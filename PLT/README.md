# PLT：MP-G2LPT V1

本目录是自然纹理全局到局部相位跟踪原型，严格限定在 `PLT` 内。方法名称为
Measurement-Preserving Global-to-Local Phase Tracking（MP-G2LPT）。当前实现覆盖深度研究报告第 53 节 V1 和第 54 节 V2：

- 首帧自然纹理 ROI anchor；4 个方向（0/45/90/135°）和 3 个 Gabor 空间波长；
- amplitude、wrapped phase、unit phasor 和 phase reliability；
- Intensity NCC、Scalar phase NCC、Single-scale circular、Multi-scale circular、POC + local multi-scale 五组对照；
- POC 全局粗定位、局部 circular phase 整数定位、复相位 WLS 亚像素残差；
- 轨迹、质量、峰值比、跨尺度一致性、WLS 残差、PNG/MP4/CSV/MAT 输出。
- V2 temporal、band-protected、spatial-common 宏观运动估计，integer crop、细相位 residual 和重建轨迹。

## 运行

在 MATLAB 中执行：

```matlab
addpath('D:\LunFu\PLT\src');
addpath('D:\LunFu\PLT\scripts');
run_reproduction                 % 带真值的合成自然纹理验证
run_all_reproduction_stages      % 执行 V1/V2 全部软件验证阶段
run_real_video                   % 先修改脚本顶部的 cfg.video.path
benchmark_real_video             % 不弹 ROI，测量 V3 真实视频前端耗时
```

`run_real_video.m` 的首帧 ROI 交互不使用按钮：当 `cfg.video.roi=[]` 时不预置矩形，直接拖动框选；双击或按 Enter 确认，按 Esc 或关闭窗口取消并安全退出。真实视频输出包括标准 V1 结果以及：

- `cfg.output.directory` 可在脚本用户配置区修改；目录必须位于当前工程的 `outputs/` 下。
- 每次运行在 ROI 确认成功后清空该固定目录，不创建时间戳目录；若 ROI 取消，则保留既有结果。
- `04_phase_tracking_overlay.mp4`：相位域 MP-G2LPT 跟踪结果。
- `05_intensity_tracking_overlay.mp4`：强度/时域 NCC 对照结果；同时记录 `intensity_tracking.csv`。
- `cfg.method.observedAxis='x'` 观测水平运动，改为 `'y'` 观测垂直运动；`'both'` 保留二维计算。
- 真实视频主跟踪使用 V3 predictive phase tracking：健康帧使用运动预测+局部相位，连续失效后才用 POC 恢复；anchor 仍作为测量参考，recent/best 仅用于跟踪适应。
- `cfg.video.processingScale=0.5` 用半分辨率处理并将轨迹换算回原图像素；改为 `1` 可恢复原始分辨率。
- `11_real_video_waveform.png/.fig`
- `12_real_video_spectrum.png/.fig`

这两个 FIG 在保存前显式固定为 `Visible='on'`。真实视频没有外部真值时只输出观测波形、频谱和质量，不伪造 RMSE/PCC。

`run_all_reproduction_stages` 还执行相位 wrapping、POC 平移、周期纹理、多扰动、large+micro 以及 temporal/band-protected/spatial 解耦测试，结果写入 `outputs/all_stages/`。
其中还包含 V3 预测、遮挡恢复和模板更新验证；`benchmark_real_video` 的运行时间结果写入 `outputs/runtime_benchmark/`。

## 目录

`src/` 存放 Gabor 特征、POC、局部相位匹配、WLS 和输出函数；`scripts/` 存放复现与真实视频入口；`third_party/matlabPyrTools/` 是按用户提供路径复制的工具箱，V1 当前不强依赖其 steerable pyramid 函数；`outputs/` 存放运行结果。

旋转/缩放和 M-PME/BPAF/AP-CV 后端仍未接入；参考 PDF 只有 crossline 论文内容且没有作者数据，因此 PLT 输出是研究报告定义的自然纹理方法验证，不宣称复现该 crossline 论文的真实实验。
