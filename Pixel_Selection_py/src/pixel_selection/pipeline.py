"""完整复现入口和 M1-M4 消融流程。"""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np

from .csp import extract_phase_features
from .features import foreground_mask_with_details, spatial_reliability
from .metrics import evaluate_spectrum
from .plots import (
    plot_figure_1_overview,
    plot_figure_2_detailed,
    plot_figure_3_features,
    plot_figure_4_reliability,
    plot_figure_5_temporal,
    plot_figure_7_spectrum,
    plot_figure_8_camera_motion,
    plot_figure_9_comparison,
    plot_figure_10_ablation,
    plot_figure_14_frame_interference,
    plot_figure_16_subblocks,
    plot_process_maps,
)
from .sparse import fista_sparse_reconstruction, temporal_reliability
from .synthetic import generate_synthetic_video


def _save_video(video: np.ndarray, path: Path, fps: float) -> None:
    height, width = video.shape[1:]
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height), False)
    for frame in video:
        writer.write(np.uint8(np.clip(frame, 0.0, 1.0) * 255.0))
    writer.release()


def _plot_outputs(video, truth, csp, fg, spatial, temporal, sparse, outputs, ablation_series):
    figures = outputs["figures"]
    plot_figure_1_overview(figures / "figure_1_overall_framework.png")
    plot_figure_2_detailed(figures / "figure_2_detailed_process.png", video, csp, fg, spatial, temporal, sparse, truth)
    plot_figure_3_features(figures / "figure_3_spatial_features.png", video, fg["mask"], spatial)
    plot_figure_4_reliability(figures / "figure_4_reliability_selection.png", video, fg["mask"], spatial)
    plot_figure_5_temporal(figures / "figure_5_temporal_reconstruction.png", temporal, sparse, truth)
    plot_figure_7_spectrum(figures / "figure_7_synthetic_spectrum.png", sparse, truth)
    plot_figure_8_camera_motion(figures / "figure_8_synthetic_camera_motion.png", truth)
    plot_figure_9_comparison(figures / "figure_9_synthetic_comparison.png", ablation_series, truth)
    plot_figure_9_comparison(figures / "figure_11_synthetic_ablation_spectra.png", ablation_series, truth)
    plot_figure_10_ablation(figures / "figure_10_ablation_configuration.png")
    plot_figure_14_frame_interference(figures / "figure_14_synthetic_frame_interference.png", video, truth)
    plot_process_maps(outputs["process"].parent, video, csp, fg, spatial, temporal, sparse, truth)

    # 对应论文 Fig. 16：将前景包围盒划分为 4×4，比较可靠像素与全像素谱。
    ys, xs = np.where(fg["mask"])
    block_series = []
    if ys.size:
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        for row in range(4):
            for col in range(4):
                ya, yb = y0 + (y1-y0)*row//4, y0 + (y1-y0)*(row+1)//4
                xa, xb = x0 + (x1-x0)*col//4, x0 + (x1-x0)*(col+1)//4
                block = np.zeros_like(fg["mask"]); block[ya:yb, xa:xb] = True
                all_mask = block & fg["mask"]
                rel_mask = block & spatial["reliable"]
                if rel_mask.sum() == 0: rel_mask = all_mask
                all_signal = csp["phase_diff"][:, all_mask].mean(axis=1)
                rel_signal = csp["phase_diff"][:, rel_mask].mean(axis=1)
                freq = np.fft.rfftfreq(len(all_signal), 1.0 / truth["fs"])
                block_series.append((row*4+col+1, freq, np.abs(np.fft.rfft(rel_signal-rel_signal.mean())), np.abs(np.fft.rfft(all_signal-all_signal.mean()))))
    plot_figure_16_subblocks(figures / "figure_16_synthetic_subblocks.png", block_series)


def run_reproduction(output_root: str | Path, frames: int = 300) -> dict:
    """运行合成等价验证并写出结果、图像、视频和 JSON。"""
    root = Path(output_root)
    dirs = {name: root / name for name in ["figures", "process", "videos", "data"]}
    for path in dirs.values(): path.mkdir(parents=True, exist_ok=True)
    video, truth = generate_synthetic_video(frames=frames)
    np.savez_compressed(dirs["data"] / "synthetic_case.npz", video=video, **truth)
    _save_video(video, dirs["videos"] / "synthetic_case.mp4", truth["fs"])

    csp = extract_phase_features(video)
    fg = foreground_mask_with_details(csp["foreground_response"])
    spatial = spatial_reliability(video, csp["phase_diff"], csp["amplitude"], fg["mask"])
    temporal_full = temporal_reliability(csp["phase_diff"], spatial["reliable"])
    sparse = fista_sparse_reconstruction(temporal_full["refined"], temporal_full["observed"], truth["fs"])
    metrics = evaluate_spectrum(sparse["spectrum_frequencies"], sparse["spectrum"], truth["vibration"], truth["fs"], truth["frequency_hz"])

    # M1-M4：论文消融实验的可复现定义；PVE/STVSA/PMD 因正文没有完整算法不伪造。
    m1_temporal = temporal_reliability(csp["phase_diff"], fg["mask"])
    m2_temporal = temporal_full
    m3_sparse = fista_sparse_reconstruction(m1_temporal["refined"], m1_temporal["observed"], truth["fs"])
    m1_freq = np.fft.rfftfreq(m1_temporal["difference"].size, d=1.0 / truth["fs"])
    m2_freq = np.fft.rfftfreq(m2_temporal["difference"].size, d=1.0 / truth["fs"])
    m1_spectrum = np.abs(np.fft.rfft(m1_temporal["difference"]))
    m2_spectrum = np.abs(np.fft.rfft(m2_temporal["difference"]))
    ablation = {
        "M1_foreground_raw": evaluate_spectrum(m1_freq, m1_spectrum, truth["vibration"], truth["fs"], truth["frequency_hz"]),
        "M2_spatial_raw": evaluate_spectrum(m2_freq, m2_spectrum, truth["vibration"], truth["fs"], truth["frequency_hz"]),
        "M3_temporal_sparse": evaluate_spectrum(m3_sparse["spectrum_frequencies"], m3_sparse["spectrum"], truth["vibration"], truth["fs"], truth["frequency_hz"]),
        "M4_full": metrics,
    }
    ablation_series = [
        ("M1", m1_freq, m1_spectrum),
        ("M2", m2_freq, m2_spectrum),
        ("M3", m3_sparse["spectrum_frequencies"], m3_sparse["spectrum"]),
        ("M4 Proposed", sparse["spectrum_frequencies"], sparse["spectrum"]),
    ]
    # 保留可用于逐式复核的中间数值，不只保存最终图片。
    np.savez_compressed(
        dirs["data"] / "intermediate_outputs.npz",
        phase_diff=csp["phase_diff"],
        amplitude=csp["amplitude"],
        foreground_response=csp["foreground_response"],
        foreground_candidates=fg["candidates"],
        foreground_union=fg["union"],
        foreground_mask=fg["mask"],
        foreground_thresholds=fg["thresholds"],
        mei=spatial["mei"], sam=spatial["sam"], pse=spatial["pse"],
        confidence_mei=spatial["confidence_mei"], confidence_sam=spatial["confidence_sam"], confidence_pse=spatial["confidence_pse"],
        confidence_fused=spatial["confidence_fused"], reliable=spatial["reliable"],
        temporal_signal=temporal_full["signal"], temporal_difference=temporal_full["difference"], refined_difference=temporal_full["refined"], observed=temporal_full["observed"],
        window_std=temporal_full["window_std"], window_range=temporal_full["window_range"], z_std=temporal_full["z_std"], z_range=temporal_full["z_range"], bad_windows=temporal_full["bad_windows"],
        sparse_frequencies=sparse["frequencies"], sparse_coefficients=sparse["coefficients"], coefficient_spectrum=sparse["coefficient_spectrum"], reconstructed=sparse["reconstructed"], spectrum_frequencies=sparse["spectrum_frequencies"], sparse_spectrum=sparse["spectrum"],
    )
    _plot_outputs(video, truth, csp, fg, spatial, temporal_full, sparse, dirs, ablation_series)
    result = {
        "status": "synthetic_equivalent_validation",
        "truth_frequency_hz": float(truth["frequency_hz"]),
        "selected_orientation": int(csp["orientation"]),
        "sigma_pixels": float(csp["sigma"]),
        "foreground_pixels": int(fg["mask"].sum()),
        "reliable_pixels": int(spatial["reliable"].sum()),
        "spatial_fallback_used": int(spatial["used_fallback"]),
        "temporal_bad_windows": int(temporal_full["bad_windows"].sum()),
        "sparse_iterations": int(sparse["iterations"]),
        "fft_peak_frequency_hz": float(sparse["peak_frequency"]),
        "coefficient_peak_frequency_hz": float(sparse["coefficient_peak_frequency"]),
        "intermediate_data": "outputs/data/intermediate_outputs.npz",
        "metrics": metrics,
        "ablation": ablation,
        "limitations": [
            "论文作者数据声明为按请求提供；本次使用合成等价视频，不宣称复现真实硬件实验。",
            "CSP 似然分布参数、时间窗口长度、异常阈值百分位和部分稀疏求解细节未完全公开，采用了明确标注的实现推断。",
        ],
    }
    (root / "reproduction_results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return result
