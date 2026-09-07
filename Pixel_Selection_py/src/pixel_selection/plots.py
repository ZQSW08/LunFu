"""按论文图形语义生成完整的过程图和正式结果图。

论文图形整体采用白底、衬线字体、细黑色坐标轴，谱图使用蓝色方法曲线和
红色虚线真值。空间特征图沿用论文中蓝底到黄/红高值的顺序色图；为了不让
颜色成为唯一编码，谱图同时使用线型和图例，掩膜图使用黑白显示。
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np

from .metrics import normalize


BLUE = "#0000FF"
RED = "#FF0000"
BLACK = "#111111"


def _style() -> None:
    plt.rcParams.update({
        "font.family": "serif",
        "font.serif": ["Times New Roman", "STIXGeneral", "DejaVu Serif"],
        "font.size": 8,
        "axes.titlesize": 8,
        "axes.labelsize": 8,
        "axes.linewidth": 0.6,
        "xtick.labelsize": 7,
        "ytick.labelsize": 7,
        "xtick.major.width": 0.5,
        "ytick.major.width": 0.5,
        "legend.fontsize": 7,
        "figure.facecolor": "white",
        "axes.facecolor": "white",
        "savefig.facecolor": "white",
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
    })


def _save(fig: plt.Figure, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # 不使用 bbox_inches='tight'，保持各图的固定物理尺寸和论文式留白。
    fig.savefig(path, dpi=300, facecolor="white")
    plt.close(fig)


def _map(ax, value, title, cmap="jet", vmin=None, vmax=None, colorbar=True):
    im = ax.imshow(value, cmap=cmap, vmin=vmin, vmax=vmax, interpolation="nearest")
    ax.set_title(title, pad=3)
    ax.set_xticks([]); ax.set_yticks([])
    if colorbar:
        ax.figure.colorbar(im, ax=ax, fraction=0.046, pad=0.02)
    return im


def _spectrum(ax, freq, measured, truth_freq, truth_signal, fs, title, xlim=(0, 40)):
    measured = normalize(measured)
    truth_f = np.fft.rfftfreq(len(truth_signal), d=1.0 / fs)
    truth_a = normalize(np.abs(np.fft.rfft(truth_signal - truth_signal.mean())))
    truth_interp = np.interp(freq, truth_f, truth_a, left=0.0, right=0.0)
    ax.plot(freq, measured, color=BLUE, linewidth=0.8, label="Proposed")
    ax.plot(freq, truth_interp, color=RED, linestyle="--", linewidth=0.75, label="Ground truth")
    ax.set_xlim(*xlim); ax.set_ylim(0, 1.05)
    ax.set_xlabel("Frequency (Hz)"); ax.set_ylabel("Norm. Amp.")
    ax.set_title(title)
    ax.legend(frameon=False, loc="upper right", handlelength=1.5)
    ax.grid(alpha=0.18, linewidth=0.35)


def plot_figure_1_overview(path: Path) -> None:
    _style(); fig, ax = plt.subplots(figsize=(7.2, 2.5), constrained_layout=True)
    ax.set_xlim(0, 3); ax.set_ylim(0, 1); ax.axis("off")
    panels = [
        (0.04, "#67B0C9", "Foreground Extraction", ["CSP filtering", "Amplitude-weighted\nphase smoothing", "Multi-frame\naccumulation"]),
        (1.04, "#6D8FD1", "Reliability-Guided Spatial\nPixel Selection", ["Feature extraction\n(MEI, SAM, PSE)", "Bayesian averaged\npooling", "Reliable pixel selection"]),
        (2.04, "#F28328", "Reliability-Guided Temporal\nSparse Reconstruction", ["Temporal reliability\nevaluation", "Sparse reconstruction\n(FISTA)", "Vibration frequency"]),
    ]
    for x, color, title, steps in panels:
        ax.add_patch(patches.FancyBboxPatch((x, .06), .88, .84, boxstyle="round,pad=.02,rounding_size=.06", facecolor="#F5F5F5", edgecolor="none"))
        ax.add_patch(patches.FancyBboxPatch((x, .78), .88, .12, boxstyle="round,pad=.02,rounding_size=.06", facecolor=color, edgecolor="none"))
        ax.text(x + .44, .84, title, ha="center", va="center", color="white", weight="bold", fontsize=8)
        for j, step in enumerate(steps):
            y = .64 - j * .22
            ax.add_patch(patches.FancyBboxPatch((x + .12, y), .64, .11, boxstyle="round,pad=.01,rounding_size=.015", facecolor="#D8E2F6" if x < 2 else "#FCE6D4", edgecolor="none"))
            ax.text(x + .44, y + .055, step, ha="center", va="center", fontsize=7)
            if j < 2: ax.annotate("", xy=(x + .44, y - .015), xytext=(x + .44, y - .08), arrowprops={"arrowstyle":"->", "lw":.5, "color":color})
    for x, c in [(0.92, "#7BAED4"), (1.92, "#E7A23A")]:
        ax.annotate("", xy=(x + .11, .48), xytext=(x, .48), arrowprops={"arrowstyle":"->", "lw":1.1, "color":c})
    ax.set_title("Fig. 1. Overall framework of the proposed method", y=-.04, fontsize=9)
    _save(fig, path)


def plot_figure_2_detailed(path: Path, video, csp, fg_detail, spatial, temporal, sparse, truth) -> None:
    _style(); fig, axes = plt.subplots(3, 4, figsize=(8.2, 6.0), constrained_layout=True)
    axes[0, 0].imshow(video[0], cmap="gray", vmin=0, vmax=1); axes[0, 0].set_title("Input frame")
    axes[0, 1].imshow(np.abs(csp["phase_diff"][len(video)//2]), cmap="gray"); axes[0, 1].set_title("Phase difference")
    axes[0, 2].imshow(csp["foreground_response"][len(video)//2], cmap="gray"); axes[0, 2].set_title("Weighted response")
    axes[0, 3].imshow(fg_detail["mask"], cmap="gray"); axes[0, 3].set_title("Foreground region")
    _map(axes[1, 0], spatial["mei"], "MEI", vmin=np.percentile(spatial["mei"], 2), vmax=np.percentile(spatial["mei"], 98))
    _map(axes[1, 1], spatial["sam"], "SAM", vmin=np.percentile(spatial["sam"], 2), vmax=np.percentile(spatial["sam"], 98))
    _map(axes[1, 2], spatial["pse"], "PSE", vmin=np.percentile(spatial["pse"], 2), vmax=np.percentile(spatial["pse"], 98))
    _map(axes[1, 3], spatial["confidence_fused"], "Bayesian averaged confidence", vmin=0, vmax=1)
    for ax in axes[0]: ax.set_xticks([]); ax.set_yticks([])
    axes[2, 0].plot(truth["times"], temporal["signal"], color=BLUE, lw=.7); axes[2, 0].set_title("u(t)"); axes[2, 0].set_xlabel("Time (s)")
    axes[2, 1].plot(truth["times"][1:], temporal["difference"], color=BLACK, lw=.6); axes[2, 1].set_title("d(t)"); axes[2, 1].set_xlabel("Time (s)")
    axes[2, 2].plot(truth["times"][1:], temporal["difference"], color="#999999", lw=.6, label="raw")
    axes[2, 2].plot(truth["times"][1:], sparse["reconstructed"], color=BLUE, lw=.7, label="FISTA")
    axes[2, 2].set_title("Refined / reconstructed"); axes[2, 2].set_xlabel("Time (s)"); axes[2, 2].legend(frameon=False)
    axes[2, 3].plot(sparse["spectrum_frequencies"], normalize(sparse["spectrum"]), color=BLUE, lw=.7); axes[2, 3].axvline(truth["frequency_hz"], color=RED, ls="--", lw=.7); axes[2, 3].set_xlim(0, 40); axes[2, 3].set_title("FFT spectrum"); axes[2, 3].set_xlabel("Frequency (Hz)")
    for ax in axes[2]: ax.grid(alpha=.18, lw=.35)
    fig.suptitle("Fig. 2. Detailed example process of the proposed method", fontsize=9)
    _save(fig, path)


def plot_figure_3_features(path: Path, video, fg, spatial) -> None:
    _style(); fig, axes = plt.subplots(1, 5, figsize=(8.4, 2.3), constrained_layout=True)
    axes[0].imshow(video[0], cmap="gray", vmin=0, vmax=1); axes[0].set_title("Input / foreground")
    axes[0].contour(fg, levels=[.5], colors=RED, linewidths=.5)
    for ax, data, title in zip(axes[1:], [spatial["mei"], spatial["sam"], spatial["pse"], spatial["confidence_fused"]], ["MEI $f_M(x,y)$", "SAM $f_S(x,y)$", "PSE $f_P(x,y)$", "Fused confidence $C_f(x,y)$"]):
        _map(ax, data, title, vmin=np.percentile(data[fg], 2) if fg.any() else None, vmax=np.percentile(data[fg], 98) if fg.any() else None)
    fig.suptitle("Fig. 3. Reliability-guided foreground pixel features", fontsize=9)
    _save(fig, path)


def plot_figure_4_reliability(path: Path, video, fg, spatial) -> None:
    _style(); fig, axes = plt.subplots(4, 4, figsize=(8.2, 6.6), constrained_layout=True)
    rows = [("MEI", "mei", "confidence_mei"), ("SAM", "sam", "confidence_sam"), ("PSE", "pse", "confidence_pse")]
    # 左列重复显示前景约束，保持论文 Fig.4 的“一个前景区域贯穿三行”语义。
    for row, (label, feature, confidence) in enumerate(rows):
        axes[row, 0].imshow(fg, cmap="gray"); axes[row, 0].set_title("Foreground $\\Omega$" if row == 0 else "")
        axes[row, 0].contour(spatial[confidence] > .9, colors=RED, linewidths=.35)
        _map(axes[row, 1], spatial[feature], f"$f_{{{label[0]}}}(x,y)$", vmin=np.percentile(spatial[feature][fg], 2), vmax=np.percentile(spatial[feature][fg], 98))
        _map(axes[row, 2], spatial[confidence], f"$C_{{{label[0]}}}(x,y)$", vmin=0, vmax=1)
        axes[row, 3].imshow(video[0], cmap="gray", vmin=0, vmax=1); axes[row, 3].contour(spatial[confidence] > .9, colors=RED, linewidths=.4); axes[row, 3].set_title(f"{label} reliable")
    _map(axes[3, 0], spatial["confidence_fused"], "$C_f(x,y)$", vmin=0, vmax=1)
    axes[3, 1].imshow(spatial["reliable"], cmap="gray"); axes[3, 1].set_title("Reliable pixels $\\mathcal{R}$")
    axes[3, 2].imshow(video[0], cmap="gray", vmin=0, vmax=1); axes[3, 2].contour(spatial["reliable"], colors=RED, linewidths=.4); axes[3, 2].set_title("Selected set")
    axes[3, 3].axis("off")
    for ax in axes.flat:
        if ax.has_data() and not ax.get_title(): ax.set_xticks([]); ax.set_yticks([])
    fig.suptitle("Fig. 4. The process of reliability-guided spatial pixel selection", fontsize=9)
    _save(fig, path)


def plot_figure_5_temporal(path: Path, temporal, sparse, truth) -> None:
    _style(); fig, axes = plt.subplots(2, 3, figsize=(8.2, 4.2), constrained_layout=True)
    axes[0, 0].plot(truth["times"], temporal["signal"], color=BLUE, lw=.7); axes[0, 0].set(title="$u(t)$", xlabel="Time (s)")
    axes[0, 1].plot(truth["times"][1:], temporal["difference"], color=BLACK, lw=.6); axes[0, 1].set(title="$d(t)$", xlabel="Time (s)")
    axes[0, 2].plot(temporal["window_std"], color=BLUE, marker=".", ms=2, lw=.6, label="$\\sigma_i$"); axes[0, 2].plot(temporal["window_range"], color=RED, marker=".", ms=2, lw=.6, label="$p_i$"); axes[0, 2].set(title="Window statistics", xlabel="Window index"); axes[0, 2].legend(frameon=False)
    axes[1, 0].plot(truth["times"][1:], temporal["difference"], color="#999999", lw=.6)
    for i, bad in enumerate(temporal["bad_windows"]):
        if bad: axes[1, 0].axvspan(i * 20 / truth["fs"], min((i + 1) * 20, len(temporal["difference"])) / truth["fs"], color=RED, alpha=.16)
    axes[1, 0].set(title="Masked abnormal windows", xlabel="Time (s)")
    axes[1, 1].plot(truth["times"][1:], sparse["reconstructed"], color=BLUE, lw=.7); axes[1, 1].set(title="FISTA reconstruction", xlabel="Time (s)")
    axes[1, 2].plot(sparse["spectrum_frequencies"], normalize(sparse["spectrum"]), color=BLUE, lw=.7); axes[1, 2].axvline(truth["frequency_hz"], color=RED, ls="--", lw=.7); axes[1, 2].set(title="Dominant frequency", xlabel="Frequency (Hz)", xlim=(0, 40), ylim=(0, 1.05))
    for ax in axes.flat: ax.grid(alpha=.18, lw=.35)
    fig.suptitle("Algorithm 1. Reliability-guided temporal sparse reconstruction", fontsize=9)
    _save(fig, path)


def plot_figure_7_spectrum(path: Path, sparse, truth) -> None:
    _style(); fig, ax = plt.subplots(figsize=(4.2, 2.8), constrained_layout=True)
    _spectrum(ax, sparse["spectrum_frequencies"], sparse["spectrum"], truth["frequency_hz"], truth["vibration"], truth["fs"], "Synthetic case")
    fig.suptitle("Fig. 7. Comparison of frequency spectra", fontsize=9)
    _save(fig, path)


def plot_figure_8_camera_motion(path: Path, truth) -> None:
    _style(); fig, axes = plt.subplots(2, 1, figsize=(5.2, 3.5), sharex=True, constrained_layout=True)
    axes[0].plot(truth["times"], truth["camera_dx"], color=BLUE, lw=.7, label="Camera displacement x")
    axes[0].plot(truth["times"], np.zeros_like(truth["times"]), color=RED, ls="--", lw=.65, label="No-motion reference")
    axes[1].plot(truth["times"], truth["camera_dy"], color=BLUE, lw=.7, label="Camera displacement y")
    axes[1].plot(truth["times"], np.zeros_like(truth["times"]), color=RED, ls="--", lw=.65, label="No-motion reference")
    for ax, label in zip(axes, ["x displacement (px)", "y displacement (px)"]):
        ax.set_ylabel(label); ax.grid(alpha=.18, lw=.35); ax.legend(frameon=False, loc="upper right")
    axes[1].set_xlabel("Time (s)")
    fig.suptitle("Fig. 8. Camera-motion assessment in the synthetic equivalent test", fontsize=9)
    _save(fig, path)


def plot_figure_14_frame_interference(path: Path, video, truth) -> None:
    _style(); ids = [0, min(49, len(video)-1), min(149, len(video)-1), min(199, len(video)-1)]
    fig, axes = plt.subplots(1, 4, figsize=(8.0, 2.2), constrained_layout=True)
    base = video[ids[0]]
    for ax, i in zip(axes, ids):
        ax.imshow(video[i], cmap="gray", vmin=0, vmax=1)
        ax.set_title(f"Frame {i+1}\nt={truth['times'][i]:.2f} s")
        ax.axis("off")
    fig.suptitle("Fig. 14. Representative frames showing camera-motion interference", fontsize=9)
    _save(fig, path)


def plot_figure_9_comparison(path: Path, series, truth) -> None:
    _style(); fig, axes = plt.subplots(2, 2, figsize=(7.0, 4.6), constrained_layout=True)
    for ax, (label, freq, spectrum) in zip(axes.flat, series):
        _spectrum(ax, freq, spectrum, truth["frequency_hz"], truth["vibration"], truth["fs"], label)
    fig.suptitle("Fig. 9. Comparison of synthetic spectra with the ground truth", fontsize=9)
    _save(fig, path)


def plot_figure_10_ablation(path: Path) -> None:
    _style(); fig, ax = plt.subplots(figsize=(8.2, 3.0), constrained_layout=True)
    ax.set_xlim(0, 10.8); ax.set_ylim(0, 4.8); ax.axis("off")
    models = [("M1", False, False), ("M2", True, False), ("M3", False, True), ("M4", True, True)]
    for j, (name, spatial, temporal) in enumerate(models):
        y = 3.9 - j * .95; ax.text(.25, y, name, weight="bold", va="center")
        boxes = [(1.0, "Source Video"), (2.3, "Foreground\nExtraction")]
        if spatial: boxes.append((4.0, "Reliability-Guided Spatial\nPixel Selection"))
        boxes.append((6.1 if spatial else 4.4, "Phase Time Series"))
        if temporal: boxes.append((7.2 if spatial else 6.2, "Reliability-Guided Temporal\nSparse Reconstruction"))
        boxes.append((8.8, "Structural Vibration\nFrequency"))
        for x, text in boxes:
            w = 1.1 if text in ["Source Video", "Phase Time Series"] else 1.45
            ax.add_patch(patches.FancyBboxPatch((x, y-.2), w, .4, boxstyle="round,pad=.02" if text in ["Source Video", "Structural Vibration\nFrequency"] else "square,pad=.01", facecolor="white", edgecolor=BLACK, lw=.6))
            ax.text(x+w/2, y, text, ha="center", va="center", fontsize=6.5)
        for (x0, _), (x1, _) in zip(boxes[:-1], boxes[1:]): ax.annotate("", xy=(x1-.05, y), xytext=(x0+1.1, y), arrowprops={"arrowstyle":"->", "lw":.5})
    ax.add_patch(patches.Rectangle((2.1, .45), 4.9, 3.85, fill=False, ec=RED, ls="--", lw=.8)); ax.text(4.55, 4.42, "Spatial Domain", ha="center", color=RED)
    ax.add_patch(patches.Rectangle((6.0, .45), 2.2, 3.85, fill=False, ec="#0066CC", ls="--", lw=.8)); ax.text(7.1, 4.42, "Time Domain", ha="center", color="#0066CC")
    ax.set_title("Fig. 10. Configurations of different models in ablation experiments", fontsize=9, pad=3)
    _save(fig, path)


def plot_figure_16_subblocks(path: Path, block_series) -> None:
    _style(); fig, axes = plt.subplots(4, 4, figsize=(7.4, 6.0), constrained_layout=True)
    for ax, (idx, freq, reliable, all_pixels) in zip(axes.flat, block_series):
        ax.plot(freq, normalize(all_pixels), color=BLUE, lw=.45, label="All pixels")
        ax.plot(freq, normalize(reliable), color=RED, lw=.45, label="Reliable pixels")
        ax.set_title(f"Block {idx}", fontsize=7); ax.set_xlim(0, 50); ax.set_ylim(0, 1.05); ax.grid(alpha=.12, lw=.25)
        ax.tick_params(labelsize=6)
    axes[0, 0].legend(frameon=False, fontsize=6, handlelength=1.2)
    fig.suptitle("Fig. 16. 4 × 4 sub-block vibration spectra (synthetic equivalent)", fontsize=9)
    _save(fig, path)


def plot_process_maps(outputs: Path, video, csp, fg_detail, spatial, temporal, sparse, truth) -> None:
    """保存每个中间阶段的单独图，便于逐式核对。"""
    _style(); process = outputs / "process"; process.mkdir(parents=True, exist_ok=True)
    frame_ids = [0, len(video)//2, len(video)-1]
    fig, axes = plt.subplots(1, 3, figsize=(6.6, 2.2), constrained_layout=True)
    for ax, i in zip(axes, frame_ids): ax.imshow(np.abs(csp["phase_diff"][i]), cmap="gray"); ax.set_title(f"Frame {i+1}"); ax.axis("off")
    fig.suptitle("Phase-difference examples", fontsize=9); _save(fig, process / "phase_difference_examples.png")
    fig, axes = plt.subplots(1, 3, figsize=(6.6, 2.2), constrained_layout=True)
    for ax, i in zip(axes, frame_ids): ax.imshow(csp["foreground_response"][i], cmap="gray"); ax.set_title(f"Frame {i+1}"); ax.axis("off")
    fig.suptitle("Amplitude-weighted smoothed response", fontsize=9); _save(fig, process / "foreground_response_examples.png")
    for key, title in [("mei", "MEI"), ("sam", "SAM"), ("pse", "PSE"), ("confidence_mei", "Confidence CM"), ("confidence_sam", "Confidence CS"), ("confidence_pse", "Confidence CP"), ("confidence_fused", "Confidence Cf")]:
        fig, ax = plt.subplots(figsize=(4.0, 3.0), constrained_layout=True); _map(ax, spatial[key], title, vmin=0 if "confidence" in key else None, vmax=1 if "confidence" in key else None); _save(fig, process / f"{key}.png")
    fig, ax = plt.subplots(figsize=(4.0, 3.0), constrained_layout=True); ax.imshow(fg_detail["union"], cmap="gray"); ax.set_title("Union before Cmax"); ax.axis("off"); _save(fig, process / "foreground_union_before_cmax.png")
    for data, name, title in [(fg_detail["mask"], "foreground_mask.png", "Foreground mask after Cmax"), (spatial["reliable"], "reliable_pixels.png", "Reliable pixel set R")]:
        fig, ax = plt.subplots(figsize=(4.0, 3.0), constrained_layout=True); ax.imshow(data, cmap="gray", interpolation="nearest"); ax.set_title(title); ax.axis("off"); _save(fig, process / name)
    fig, ax = plt.subplots(figsize=(5.0, 2.8), constrained_layout=True); ax.plot(fg_detail["thresholds"], color=BLUE, lw=.7); ax.set(title="Per-frame adaptive threshold", xlabel="Frame", ylabel="$\\mu_t+\\sigma_t$"); ax.grid(alpha=.18, lw=.35); _save(fig, process / "foreground_thresholds.png")
    fig, axes = plt.subplots(1, 2, figsize=(6.8, 2.6), constrained_layout=True); axes[0].plot(truth["times"], temporal["signal"], color=BLUE, lw=.7); axes[0].set(title="$u(t)$", xlabel="Time (s)"); axes[1].plot(truth["times"][1:], temporal["difference"], color=BLACK, lw=.6); axes[1].set(title="$d(t)$", xlabel="Time (s)");
    for ax in axes: ax.grid(alpha=.18, lw=.35)
    _save(fig, process / "temporal_signal_and_difference.png")
    fig, ax = plt.subplots(figsize=(5.0, 2.8), constrained_layout=True); ax.plot(temporal["z_std"], color=BLUE, lw=.7, label="$z_i^{(\\sigma)}$"); ax.plot(temporal["z_range"], color=RED, lw=.7, label="$z_i^{(p)}$"); ax.axhline(temporal["tau"], color=BLACK, ls="--", lw=.6); ax.axhline(-temporal["tau"], color=BLACK, ls="--", lw=.6); ax.set(title="Robust Z-scores and adaptive threshold", xlabel="Window index"); ax.legend(frameon=False); ax.grid(alpha=.18, lw=.35); _save(fig, process / "temporal_window_zscores.png")
    fig, ax = plt.subplots(figsize=(5.0, 2.8), constrained_layout=True); ax.plot(sparse["frequencies"], normalize(sparse["coefficient_spectrum"]), color=BLUE, lw=.7); ax.set(xlim=(0, 50), ylim=(0, 1.05), title="FISTA sparse coefficient spectrum", xlabel="Frequency (Hz)", ylabel="Norm. coefficient"); ax.grid(alpha=.18, lw=.35); _save(fig, process / "sparse_coefficients.png")
