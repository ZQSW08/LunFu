"""复杂可转向金字塔相位提取。

论文使用 Complex Steerable Pyramid (CSP)。当前环境有 pyrtools，因此这里
使用其频域 steerable pyramid 实现，尺度 0 对应最高空间频率子带；这与论文
“优先使用最小尺度”的描述一致。边界为周期边界，属于实现条件而非论文明确
给出的边界设置。
"""

from __future__ import annotations

import numpy as np
from scipy.ndimage import gaussian_filter
from pyrtools.pyramids import SteerablePyramidFreq


def extract_phase_features(
    video: np.ndarray,
    pyramid_height: int = 2,
    order: int = 3,
    scale: int = 0,
    sigma_ref: float = 2.0,
    reference_shape: tuple[int, int] = (1080, 1440),
) -> dict[str, np.ndarray | int | float]:
    """提取所有方向的 CSP 振幅和相对第一帧的相位差。

    Parameters
    ----------
    video:
        ``(T, H, W)`` 灰度视频，取值范围建议为 [0, 1]。
    scale:
        CSP 尺度；论文建议使用最小尺度，默认 0。
    """
    if video.ndim != 3:
        raise ValueError("video 必须是 (T,H,W) 灰度数组")
    video = np.asarray(video, dtype=np.float32)
    frames, height, width = video.shape
    sigma_candidate = sigma_ref * min(height, width) / min(reference_shape)
    sigma = float(np.clip(sigma_candidate, 1.0, 3.0))

    # 先在每个方向保留复数子带，便于依据平均幅值选择主方向。
    first = SteerablePyramidFreq(video[0], height=pyramid_height, order=order, is_complex=True)
    orientations = first.num_orientations
    coeffs = np.empty((frames, orientations, height // (2**scale), width // (2**scale)), dtype=np.complex64)
    amplitude = np.empty_like(coeffs.real)
    for t, frame in enumerate(video):
        pyramid = SteerablePyramidFreq(frame, height=pyramid_height, order=order, is_complex=True)
        for ori in range(orientations):
            band = np.asarray(pyramid.pyr_coeffs[(scale, ori)], dtype=np.complex64)
            coeffs[t, ori] = band
            amplitude[t, ori] = np.abs(band)

    # 论文将方向与主振动方向对齐；无传感器方向时用全序列平均响应选择。
    orientation = int(np.argmax(amplitude.mean(axis=(0, 2, 3))))
    selected = coeffs[:, orientation]
    selected_amp = amplitude[:, orientation]
    ref = selected[0]
    phase_diff = np.angle(selected * np.conj(ref)[None, :, :]).astype(np.float32)

    # 若 CSP 尺度不是 0，统一上采样到视频分辨率，便于与掩膜对齐。
    if phase_diff.shape[1:] != (height, width):
        from cv2 import resize, INTER_LINEAR

        phase_diff = np.stack([resize(x, (width, height), interpolation=INTER_LINEAR) for x in phase_diff])
        selected_amp = np.stack([resize(x, (width, height), interpolation=INTER_LINEAR) for x in selected_amp])

    # 对应式 (13)-(15)：幅值加权、分辨率自适应的空间平滑。
    weighted = np.abs(phase_diff) * selected_amp
    smoothed = np.stack([gaussian_filter(x, sigma=sigma, truncate=3.0) for x in weighted]).astype(np.float32)
    return {
        "phase_diff": phase_diff,
        "amplitude": selected_amp.astype(np.float32),
        "foreground_response": smoothed,
        "orientation": orientation,
        "sigma": sigma,
        "num_orientations": orientations,
    }
