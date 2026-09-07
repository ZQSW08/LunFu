"""论文式 (38)-(42) 频谱指标。"""

from __future__ import annotations

import numpy as np


def normalize(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=np.float64)
    peak = np.max(np.abs(values))
    return values / peak if peak > 0 else values


def evaluate_spectrum(
    frequencies: np.ndarray,
    measured_spectrum: np.ndarray,
    truth_signal: np.ndarray,
    fs: float,
    truth_frequency: float,
) -> dict[str, float]:
    """计算 PF、FE、PER、RMSE、PCC；参考谱插值到稀疏字典网格。"""
    measured = normalize(measured_spectrum)
    ref_freq = np.fft.rfftfreq(len(truth_signal), d=1.0 / fs)
    ref_spec = normalize(np.abs(np.fft.rfft(truth_signal - np.mean(truth_signal))))
    reference = np.interp(frequencies, ref_freq, ref_spec, left=0.0, right=0.0)
    if np.max(reference) > 0:
        reference = normalize(reference)
    peak_index = int(np.argmax(measured))
    pf = float(frequencies[peak_index])
    per = float(measured[peak_index] ** 2 / (np.sum(measured * measured) + 1e-12))
    rmse = float(np.sqrt(np.mean((measured - reference) ** 2)))
    if np.std(measured) < 1e-12 or np.std(reference) < 1e-12:
        pcc = 0.0
    else:
        pcc = float(np.corrcoef(measured, reference)[0, 1])
    return {"PF_Hz": pf, "FE_Hz": abs(pf - truth_frequency), "PER": per, "RMSE": rmse, "PCC": pcc}
