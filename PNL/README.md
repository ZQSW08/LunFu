# PNL：Stereo photogrammetry 中相位非线性抑制的论文复现

本目录是 `D:\LunFu` 总项目集合中的独立论文复现单元。本对话产生的代码、工具、数据说明和输出均限定在 `D:\LunFu\PNL`，不会修改其他论文目录。

## 快速运行

在 MATLAB R2022b 中执行：

```matlab
cd('D:\LunFu\PNL');
addpath(genpath('D:\LunFu\PNL\src'));
addpath('D:\LunFu\PNL\scripts');
results = run_pnl_reproduction('demo');
```

`demo` 默认使用标记附近的 128×128 ROI 和论文 200 fps/2 s 轨迹；`paper` 使用 256×256 ROI。论文完整 1600×1100 相机画幅已保留在配置中，但不建议直接对完整画幅逐帧计算。

## 真实视频入口

真实双目视频入口位于 scripts/run_real_video_entry.m。它接收左右视频和 CalibrationFile，支持 P{1}/P{2}、P1/P2 或 stereoParams 标定格式，并将真实视频结果单独写入 outputs/real/。

示例调用：

    addpath(genpath('D:\LunFu\PNL\src'));
    addpath('D:\LunFu\PNL\scripts');
    out = run_real_video_entry( ...
        'D:\data\left.avi', 'D:\data\right.avi', ...
        'CalibrationFile', 'D:\data\calibration.mat', ...
        'Roi', [401 251 256 256], ...
        'InitialPoints', [529 532; 379 381], ...
        'MaxFrames', 400);

Roi 使用原始图像中的 [x y width height]；InitialPoints 的每一列是一个相机的 [u;v] 初始像点。入口默认最多读取 400 帧，真实长视频应确认内存后再设置 MaxFrames=Inf。

该入口已经用模拟 AVI 拆分出的左右短视频完成 30 帧 I/O 链路验证，但尚未用论文真实 FLIR 数据运行。

## 代码对应关系

- `src/complex_gabor_kernel.m`：论文 Eq. (5) 的复数 Gabor 滤波器；
- `src/phase_flow_sequence.m`：论文 Eq. (8)-(11) 的相位光流、PNL 与置信度加权；
- `src/simulate_stereo_sequence.m`：十字线、透视投影、模糊、噪声与真值；
- `src/triangulate_stereo_sequence.m`：对应论文 Eq. (1)-(3) 的双目 DLT 三角测量；
- `src/local_coordinates.m`：对应论文 Eq. (4) 的局部坐标转换；
- `src/compute_ods.m`：按参考点 cross-power/auto-power 比值提取 ODS；
- `src/estimate_klt_sequence.m`：MATLAB PointTracker 参考方法；
- `src/write_simulation_videos.m`：写出 200 fps 双目耦合运动和 18 s 指数增幅模拟视频；
- `src/plot_paper_figures.m`：按论文信息结构输出 Fig. 1-10、18-19 风格图；
- `scripts/run_pnl_reproduction.m`：核心仿真、噪声扫描、幅值扫描及结果绘图。

关键论文参数来自原文：十字线 16×16 mm、线长 14 mm、线宽 1 mm；相机约 3000 px 焦距、278 mm baseline；通用滤波器 `f=1/8, sigmaA=sigmaR=3`；几何匹配滤波器 `T=5.4 px, sigmaA=sigmaR=2T`。

## 依赖与外部代码

- `external/matlabPyrTools/`：用户提供的 MATLAB Pyramid Tools，已原样复制；本 baseline 不强制依赖它。
- `external/PeterKovesiImage/`：Peter Kovesi 图像/相位处理参考代码，尤其是 `PhaseCongruency/gaborconvolve.m`；本项目的 Gabor 实现独立保留，避免把外部函数的边界/频率约定未经核对地替换进论文流程。

## 复现边界

论文真实实验的 Data availability 声明为作者无权共享数据。本项目因此完成“基于论文参数的软件仿真复现”和可接入接口，未伪造三层钢架、LDV、加速度计或 13 组照度/增益实验结果。详见 `data/README.md`。

模拟视频：

- `outputs/videos/simulation_coupled_stereo.avi`：Fig. 5 的 X/Z 耦合运动，200 fps；
- `outputs/videos/simulation_amplitude_stereo.avi`：Fig. 18 的 30 Hz、18 s 指数增幅运动，200 fps。
