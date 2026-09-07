"""论文式 (30)-(37) 的时间可靠性检测和 FISTA 稀疏重构。"""

from __future__ import annotations

import numpy as np


def _robust_z(values: np.ndarray) -> np.ndarray:
    med = np.median(values)
    mad = np.median(np.abs(values - med))
    scale = 1.4826 * mad
    if scale < 1e-10:
        scale = float(np.std(values) + 1e-10)
    return (values - med) / scale


def temporal_reliability(
    phase_diff: np.ndarray,
    reliable: np.ndarray,
    window_frames: int = 20,
    percentile: float = 90.0,
) -> dict[str, np.ndarray | float | int]:
    """平均可靠像素、做一阶差分并按稳健 Z 分数屏蔽异常窗口。"""
    if reliable.sum() == 0:
        raise ValueError("可靠像素集为空")
    signal = phase_diff[:, reliable].mean(axis=1).astype(np.float64)
    d = np.diff(signal)
    nwin = int(np.ceil(len(d) / window_frames))
    stds = np.empty(nwin)
    ranges = np.empty(nwin)
    for i in range(nwin):
        seg = d[i * window_frames : min((i + 1) * window_frames, len(d))]
        stds[i] = np.std(seg)
        ranges[i] = np.max(seg) - np.min(seg)
    z_std = _robust_z(stds)
    z_range = _robust_z(ranges)
    scores = np.maximum(np.abs(z_std), np.abs(z_range))
    tau = float(np.percentile(np.abs(np.r_[z_std, z_range]), percentile))
    bad_windows = scores > tau
    observed = np.ones(len(d), dtype=bool)
    for i, bad in enumerate(bad_windows):
        if bad:
            observed[i * window_frames : min((i + 1) * window_frames, len(d))] = False
    # 若自适应分位数把全部窗口屏蔽，保留最稳定的窗口避免数值退化。
    if observed.sum() < max(8, len(d) // 20):
        observed[:] = False
        keep = np.argsort(scores)[: max(1, nwin // 2)]
        for i in keep:
            observed[i * window_frames : min((i + 1) * window_frames, len(d))] = True
    refined = d.copy()
    refined[~observed] = 0.0
    return {
        "signal": signal,
        "difference": d,
        "refined": refined,
        "observed": observed,
        "window_std": stds,
        "window_range": ranges,
        "z_std": z_std,
        "z_range": z_range,
        "bad_windows": bad_windows,
        "tau": tau,
    }


def _soft_threshold(x: np.ndarray, threshold: float) -> np.ndarray:
    return np.sign(x) * np.maximum(np.abs(x) - threshold, 0.0)


def fista_sparse_reconstruction(
    signal: np.ndarray,
    observed: np.ndarray,
    fs: float,
    fmin: float = 0.1,
    fmax: float = 50.0,
    df: float = 0.01,
    lambda_reg: float = 0.01,
    max_iter: int = 350,
    tol: float = 1e-6,
) -> dict[str, np.ndarray | float | int]:
    """使用 FISTA 求解带观测掩膜的 L1 正弦字典重构。

    论文只写出 sin 基函数，因此默认严格采用 sin 字典；时间零点固定为
    第一个差分样本。候选频率为论文给出的 0.1--50 Hz、0.01 Hz 间隔。
    """
    y = np.asarray(signal, dtype=np.float64)
    mask = np.asarray(observed, dtype=bool)
    t = np.arange(y.size, dtype=np.float64) / fs
    frequencies = np.arange(fmin, fmax + df / 2.0, df, dtype=np.float64)
    dictionary = np.sin(2.0 * np.pi * t[:, None] * frequencies[None, :])
    dictionary_obs = dictionary[mask]
    y_obs = y[mask]
    if y_obs.size == 0:
        raise ValueError("时间掩膜后没有可观测样本")
    # Lipschitz 常数取 Gram 矩阵最大特征值；该规模在本地复现中可承受。
    lipschitz = float(np.linalg.norm(dictionary_obs, ord=2) ** 2 + 1e-12)
    coeff = np.zeros(frequencies.size, dtype=np.float64)
    momentum = coeff.copy()
    q = 1.0
    previous_obj = None
    for iteration in range(1, max_iter + 1):
        residual = dictionary_obs @ momentum - y_obs
        gradient = dictionary_obs.T @ residual
        next_coeff = _soft_threshold(momentum - gradient / lipschitz, lambda_reg / lipschitz)
        next_q = (1.0 + np.sqrt(1.0 + 4.0 * q * q)) / 2.0
        momentum = next_coeff + ((q - 1.0) / next_q) * (next_coeff - coeff)
        coeff = next_coeff
        q = next_q
        if iteration % 10 == 0 or iteration == 1:
            obj = 0.5 * np.sum((dictionary_obs @ coeff - y_obs) ** 2) + lambda_reg * np.sum(np.abs(coeff))
            if previous_obj is not None and abs(previous_obj - obj) <= tol * max(1.0, previous_obj):
                break
            previous_obj = obj
    reconstructed = dictionary @ coeff
    # 论文式 (37)-(38) 明确要求对重构信号做 FFT 并从 FFT 谱取 PF。
    # 同时保留字典系数峰值作为诊断信息，但不把它冒充正式 PF。
    fft_frequency = np.fft.rfftfreq(reconstructed.size, d=1.0 / fs)
    fft_spectrum = np.abs(np.fft.rfft(reconstructed - reconstructed.mean()))
    fft_peak_index = int(np.argmax(fft_spectrum))
    coefficient_peak_index = int(np.argmax(np.abs(coeff)))
    return {
        "frequencies": frequencies,
        "coefficients": coeff,
        "reconstructed": reconstructed,
        "coefficient_spectrum": np.abs(coeff),
        "spectrum_frequencies": fft_frequency,
        "spectrum": fft_spectrum,
        "fft_frequency": fft_frequency,
        "fft_spectrum": fft_spectrum,
        "peak_frequency": float(fft_frequency[fft_peak_index]),
        "coefficient_peak_frequency": float(frequencies[coefficient_peak_index]),
        "iterations": iteration,
        "lipschitz": lipschitz,
    }
