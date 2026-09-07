"""用于等价软件验证的合成视频，不冒充论文真实实验数据。"""

from __future__ import annotations

import cv2
import numpy as np


def _warp(image: np.ndarray, dx: float, dy: float) -> np.ndarray:
    h, w = image.shape
    matrix = np.float32([[1.0, 0.0, dx], [0.0, 1.0, dy]])
    return cv2.warpAffine(image, matrix, (w, h), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT101)


def generate_synthetic_video(
    frames: int = 300,
    fs: float = 100.0,
    height: int = 128,
    width: int = 192,
    vibration_hz: float = 10.0,
    vibration_amplitude_px: float = 0.8,
    seed: int = 7,
) -> tuple[np.ndarray, dict[str, np.ndarray | float | int]]:
    """生成带结构振动、相机扰动和一次短时干扰的纹理视频。"""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:height, 0:width]
    # 背景保持低纹理，仅保留少量固定标记；这样可检验论文的“前景优先”
    # 假设，而不是让整幅背景的纹理响应淹没结构目标。
    background = 0.30 + 0.008 * np.sin(xx / 9.0) + 0.006 * np.cos(yy / 11.0)
    background[12:24, 18:42] += 0.12
    background += 0.006 * cv2.GaussianBlur(rng.normal(size=(height, width)).astype(np.float32), (0, 0), 1.2)
    # 结构目标：具有明显边缘和纹理，模拟 CSP 能稳定提取相位的位置。
    target_mask = np.zeros((height, width), np.float32)
    target_mask[35:105, 62:132] = 1.0
    target = 0.58 + 0.25 * np.sin(xx / 2.2) + 0.18 * np.cos(yy / 3.7)
    target += 0.08 * np.sin((xx + yy) / 1.8)
    target = np.clip(target, 0.0, 1.0).astype(np.float32)
    times = np.arange(frames) / fs
    vibration = vibration_amplitude_px * np.sin(2.0 * np.pi * vibration_hz * times)
    camera_dx = 0.16 * np.sin(2.0 * np.pi * 0.65 * times) + 0.05 * np.sin(2.0 * np.pi * 1.7 * times)
    camera_dy = 0.12 * np.cos(2.0 * np.pi * 0.45 * times)
    burst = np.exp(-0.5 * ((times - 1.85) / 0.055) ** 2)
    camera_dx += 0.8 * burst
    camera_dy -= 0.5 * burst
    video = np.empty((frames, height, width), np.float32)
    for i in range(frames):
        moving_target = _warp(target, 0.0, float(vibration[i]))
        frame = background * (1.0 - target_mask) + moving_target * target_mask
        frame = _warp(frame, float(camera_dx[i]), float(camera_dy[i]))
        frame += rng.normal(0.0, 0.006, size=frame.shape).astype(np.float32)
        video[i] = np.clip(frame, 0.0, 1.0)
    truth = {
        "times": times,
        "vibration": vibration,
        "camera_dx": camera_dx,
        "camera_dy": camera_dy,
        "target_mask": target_mask.astype(bool),
        "frequency_hz": vibration_hz,
        "fs": fs,
    }
    return video, truth
