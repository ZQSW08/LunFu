"""论文式 (16)-(29) 的前景和空间可靠性计算。"""

from __future__ import annotations

import cv2
import numpy as np
from scipy.ndimage import uniform_filter


def _largest_component(mask: np.ndarray) -> np.ndarray:
    """保留最大连通域，对应论文中的 C_max。"""
    num_labels, label_image, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    if num_labels <= 1:
        return mask.astype(bool)
    largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return label_image == largest


def foreground_mask(foreground_response: np.ndarray) -> np.ndarray:
    """按每帧均值加标准差阈值累积多帧前景区域。"""
    return foreground_mask_with_details(foreground_response)["mask"]


def foreground_mask_with_details(foreground_response: np.ndarray) -> dict[str, np.ndarray]:
    """返回式 (16) 所需的逐帧阈值、候选累积图和最终最大连通域。"""
    response = np.abs(np.asarray(foreground_response, dtype=np.float32))
    union = np.zeros(response.shape[1:], dtype=bool)
    thresholds = np.empty(response.shape[0], dtype=np.float32)
    candidates = np.empty_like(response, dtype=bool)
    for i, frame in enumerate(response):
        thresholds[i] = float(frame.mean() + frame.std())
        candidates[i] = frame > thresholds[i]
        union |= candidates[i]
    return {
        "mask": _largest_component(union),
        "union": union,
        "candidates": candidates,
        "thresholds": thresholds,
    }


def _sigmoid(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, -60.0, 60.0)
    return 1.0 / (1.0 + np.exp(-x))


def _confidence(feature: np.ndarray, valid: np.ndarray, higher_is_reliable: bool) -> np.ndarray:
    """经验 Bayes 置信度近似。

    论文给出似然比和 sigmoid，但没有给出两类分布的参数或训练标签。
    这里用前景内上下半分位的稳健高斯估计构造 log-likelihood ratio，
    并在结果中保留该实现推断，避免把未公开参数误写成论文设置。
    """
    values = feature[valid].astype(np.float64)
    out = np.zeros_like(feature, dtype=np.float32)
    if values.size < 8:
        out[valid] = 0.5
        return out
    median = np.median(values)
    low = values[values <= median]
    high = values[values >= median]
    eps = 1e-8
    mu0, sd0 = float(low.mean()), float(low.std() + eps)
    mu1, sd1 = float(high.mean()), float(high.std() + eps)
    if not higher_is_reliable:
        mu0, mu1 = mu1, mu0
        sd0, sd1 = sd1, sd0
    x = feature.astype(np.float64)
    logp1 = -0.5 * ((x - mu1) / sd1) ** 2 - np.log(sd1)
    logp0 = -0.5 * ((x - mu0) / sd0) ** 2 - np.log(sd0)
    out[valid] = _sigmoid(logp1[valid] - logp0[valid]).astype(np.float32)
    return out


def spatial_reliability(
    video: np.ndarray,
    phase_diff: np.ndarray,
    amplitude: np.ndarray,
    foreground: np.ndarray,
    neighborhood: int = 7,
    threshold: float = 0.9,
    fallback_fraction: float = 0.10,
) -> dict[str, np.ndarray | int | float]:
    """计算 MEI、SAM、PSE、三张置信图和可靠像素集 R。"""
    video = np.asarray(video, dtype=np.float32)
    valid = np.asarray(foreground, dtype=bool)
    diff = np.diff(video, axis=0)
    # 式 (18)-(20)：邻域绝对差均值和局部差分方差的时间平均。
    local_mean_abs = uniform_filter(np.abs(diff), size=(1, neighborhood, neighborhood), mode="nearest")
    local_mean_sq = uniform_filter(diff * diff, size=(1, neighborhood, neighborhood), mode="nearest")
    local_var = np.maximum(local_mean_sq - local_mean_abs * local_mean_abs, 0.0)
    mei = np.sqrt(local_var).mean(axis=0)
    # 式 (21)：平均 CSP 局部振幅。
    sam = np.asarray(amplitude, dtype=np.float32).mean(axis=0)
    # 式 (22)-(24)：非负频谱归一化后的谱熵，排除 DC 以减少漂移影响。
    spectrum = np.abs(np.fft.rfft(phase_diff - phase_diff.mean(axis=0), axis=0))
    prob = spectrum / (spectrum.sum(axis=0, keepdims=True) + 1e-12)
    pse = -(prob * np.log(prob + 1e-12)).sum(axis=0)

    cm = _confidence(mei, valid, higher_is_reliable=True)
    cs = _confidence(sam, valid, higher_is_reliable=True)
    cp = _confidence(pse, valid, higher_is_reliable=False)
    fused = (cm + cs + cp) / 3.0
    reliable = valid & (fused > threshold)

    # 论文未提供似然参数，极端输入可能没有像素通过 0.9；保留最高分的
    # 少量前景像素以保证后续算法链可运行，并在 metadata 中标记 fallback。
    used_fallback = 0
    if reliable.sum() == 0 and valid.any():
        count = max(1, int(valid.sum() * fallback_fraction))
        indices = np.flatnonzero(valid)
        selected = indices[np.argsort(fused.flat[indices])[-count:]]
        reliable.flat[selected] = True
        used_fallback = 1
    return {
        "mei": mei.astype(np.float32),
        "sam": sam.astype(np.float32),
        "pse": pse.astype(np.float32),
        "confidence_mei": cm,
        "confidence_sam": cs,
        "confidence_pse": cp,
        "confidence_fused": fused.astype(np.float32),
        "reliable": reliable,
        "used_fallback": used_fallback,
    }
