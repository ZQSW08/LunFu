# TDDM MATLAB 论文复现工程

本目录对应论文：`A point tracking method of TDDM for vibration measurement and large-scale rotational motion tracking`（Measurement 193, 2022, 110827）。所有工程文件、工具和输出都限定在本目录内。

## 运行

在 MATLAB 当前目录切换到本目录后执行：

```matlab
summary = main();
```

入口按以下顺序执行：数学单元测试、四类合成数值实验、振动实验、旋转实验和消融实验。没有论文原始视频/激光数据时，振动和旋转模块会自动执行“代理合成复现”，并在结果中标明 `proxy`；提供真实数据文件夹后，可用：

```matlab
summary = main('vibrationFolder', 'D:/path/to/vibration', ...
               'rotationFolder', 'D:/path/to/rotation');
```

直接运行真实视频时，打开 `scripts/run_real_video.m`，只修改顶部配置区，然后运行该脚本：

```matlab
run('D:/LunFu/TDDM/scripts/run_real_video.m');
```

脚本默认 `config.roi=[]` 并开启 `config.selectROI=true`，运行时会显示首帧供用户拖动矩形框选 ROI，双击或 Enter 确认，关闭窗口取消。结果会写入 `results/real_video/<视频名>/`；如果显式填写 `config.outputDirectory`，该路径就是本次结果目录，不会再追加 `outputName`。输出包括：

- `01_roi_selection.png`、`02_roi_first_frame.png`、`roi_trajectory.csv`、`tddm_local_roi_trajectory.csv`；
- `03_roi_follow_cropped_video.avi`：跟随 ROI 裁剪视频；
- `04_roi_follow_tracking_video.avi`：原图上的跟随 ROI 和最终测点标注视频，写出后会立即回读首帧验证；
- `06_tddm_<axis>_waveform.png/.fig` 和 `07_tddm_<axis>_spectrum.png/.fig`；
- `process/frame_*.png`：论文方法链的代表性中间结果；
- `tddm_trace.csv`、`tddm_results.mat`。

如需脚本化运行，可直接调用 `run_tddm_real_video(config)`；`config` 中的 ROI 使用 `[x,y,width,height]`，坐标为 `[列,行]`。`config.followROI=true` 时 ROI 随 TDDM 结果跟随目标，`config.analysisAxes` 可设为 `'x'`、`'y'` 或 `'xy'`。没有真实标定时将 `config.pxPerMM=NaN`，波形和频谱只解释为 pixel；`config.fpsOverride=[]` 时使用视频元数据帧率，只有已知采集帧率时才覆盖；`config.runBaselines=true` 才运行 KLT/Detection 对照。频谱是去均值后的 FFT 单边幅度谱，不是 PSD；频谱图使用峰值归一化幅度（最大值为 1）、线性坐标和可配置显示上限 `spectrumMaxHz`，FIG 文件保存为 `Visible='on'`，便于 MATLAB 中继续编辑。

## 目录

- `src/`：TDDM 主算法、检测、融合、IC-GN 和指标。
- `experiments/`：论文第 3 节、振动、旋转及消融实验。
- `scripts/run_real_video.m`：真实视频直接运行入口。
- `tests/`：最小数学与坐标验证。
- `data/raw/`：预留真实数据位置，不覆盖用户原始文件。
- `results/`：正式图、过程图、MAT 结果和 CSV 摘要。
- `third_party/matlabPyrTools/`：用户提供并复制进来的 MATLAB pyramid 工具。
- `third_party/ADIC2D/`：按用户指定地址克隆的 GPL-3.0 ADIC2D，用于 affine IC-GN 适配与交叉验证。

## 复现边界

论文原始实验视频、激光位移数据、完整相机几何和旋转翼真实图像未随论文 PDF 提供，因此本工程可以完整运行算法链和合成/代理实验，但不能把代理结果称为论文真实硬件实验的逐帧复现。真实数据接口保留了论文的采样率、分辨率、像素-毫米转换和评价指标。

## 当前输出

- `results/synthetic/`：亮度、噪声、运动模糊、离面旋转四组 Fig.7/9/11/13 风格曲线，以及对应的均值±标准差图；另含 `synthetic_translation.avi` 和逐帧 `synthetic_video_tddm_trace.csv`。
- `results/vibration/`：640 Hz、4096 帧代理视频，`vibration.png` 为 Fig.16 风格的三行时域/频域对照，`vibration_tddm_trace.csv` 保存每帧的 Tracking、Detection、Correction、IC-GN 和失败原因。
- `results/rotation/`：500 Hz、120 帧三标记代理视频，`rotation_frames.png` 对应 Fig.17 帧序列，`rotation.png` 对应 KLT/TDDM 轨迹对照；每个标记另有逐帧 trace CSV。
- `results/process/`：代表帧的六面板过程图，包含上一帧跟踪、四路位置、局部 ROI、CLAHE/纹理增强、Canny 边缘证据和 NCC/ZNSSD/IC-GN 数值。

代理视频使用 Motion JPEG AVI 以便 MATLAB `VideoReader` 回读；因此视频回读结果可能比内存中直接处理略有压缩误差，最终统计以结果 MAT/CSV 中标注的实际数据流为准。真实视频处理时，`config.progressEveryFrames=25` 控制进度打印间隔，`config.showProgress=true` 开启进度显示；顺序流读取和局部一次 NCC 搜索用于减少逐帧随机 seek 及重复模板匹配开销。

## 坐标约定

图像坐标使用 MATLAB 的 `[x, y] = [column, row]`，位移正方向为右、下。IC-GN 的参数为 `q = [u v ux uy vx vy]'`，局部坐标原点位于参考点；最终位置为 `referenceCenter + q(1:2)'`。

## 第三方代码说明

ADIC2D 来自 [SUMatEng/ADIC2D](https://github.com/SUMatEng/ADIC2D)，本工程只通过适配层复用其 `SubCorr`/`SFExpressions` 的一阶 IC-GN 数值步骤，并保留原仓库的 `LICENSE`。若结果用于论文或报告，应同时引用 Atkinson and Becker, *A 117 Line 2D Digital Image Correlation Code Written in MATLAB*, Remote Sensing, 2020。
