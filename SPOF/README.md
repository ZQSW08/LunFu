# SPOF 论文复现工程

本目录用于复现 Zang 等人的论文：**Structural phase optical flow: A visual vibration measurement method based on edge-guided and locally smooth priors**（Mechanical Systems and Signal Processing, 244, 113754, 2026）。

## 当前交付内容

- `src/`：SPOF 核心算法、Gabor 相位光流、置信度建模、加权 GMM-EM、异常点修复、位移积分和评价指标。
- `scripts/run_paper_reproduction.m`：生成等价合成实验，运行 POF、AW-POF、MP-POF、PNOF、SPOF 对比，并生成论文实验清单对应的参数/场景结果。
- `scripts/run_real_video.m`：真实视频入口；可选 accelerometer CSV 作为参考信号。
- `outputs/figures/`：正式结果图；`outputs/process/`：过程图；`outputs/videos/`：合成演示视频。
- `outputs/paper_reproduction_metrics.csv`、`runtime_comparison.csv`、`threshold_sensitivity.csv`、`roi_sensitivity.csv`：指标与运行时间账本。
- `experiments/EXPERIMENTS.md`：只保留正式复现实验记录。
- `external/matlabPyrTools/`：用户提供的 MATLAB 金字塔工具副本。
- `external/vidmag_reference/`：相关相位视频处理参考代码的浅克隆。

## 运行环境

- MATLAB R2022b 或更新版本。
- 本实现核心只依赖 MATLAB 基础矩阵、卷积、插值和绘图函数；不强制依赖 Image Processing Toolbox。
- 可选：`VideoReader`/`VideoWriter` 支持真实视频和演示视频读写。

## 快速运行

在 MATLAB 中：

```matlab
cd('D:/LunFu/SPOF');
run('scripts/run_paper_reproduction.m');
```

脚本默认运行短时等价合成实验，以便在普通电脑上完成验证。若要运行较长序列，可在脚本顶部将 `opts.quick = false`。

## 论文忠实性与限制

论文明确给出了 SPOF 的 Gabor 相位光流、边缘集中/局部平滑先验、二成分 GMM-EM、异常点修复、ROI 积分和线性去趋势公式；这些部分在 `src/spof_measure.m` 中按公式实现。

论文真实实验数据未随文公开，原文 Data availability 写明需向作者申请。因此本地脚本提供的是基于论文采样率、运动类型和评价指标的**等价合成复现**，不能宣称已经复现作者的真实相机/加速度计采集结果。真实视频应通过 `scripts/run_real_video.m` 进入同一算法链。

POF、AW-POF、MP-POF、PNOF 的原始实现没有随论文提供；本工程中的对应入口是用于统一比较的兼容近似，其中 SPOF 是本工程的主复现对象。

## 单位与坐标

- 光流：像素/秒；x 向右为正，y 向下为正。
- 合成真值和输出位移：像素；如有标定比例，可乘以 `scaleMmPerPixel` 转为毫米。
- 论文中的物理比例（如 0.0867 mm/Px、0.6917 mm/Px、2.6256 mm/Px、4.3281 mm/Px）只属于各真实实验，不会硬编码到合成数据。
