# BPAF 论文复现

本目录独立复现 Zang 等发表于 *Measurement* 240 (2025) 115559 的论文：
“Video-based subtle vibration measurement in the presence of large motions”。
所有代码、数据缓存和结果均限制在 `BPAF/` 内，不依赖同级其他论文工程。

## 已完成内容

- 复可转向金字塔最高空间频带的局部相位与幅值提取；
- 论文式(12)-(22)的 DoG 带通加速度滤波器及遗传算法求参；
- Acc2017、Acc2018、Acc2022 的 LoG 对比核；
- 相位展开、非线性跃变抑制、论文式(28)空间幅值加权；
- PF、PER、RMSE、PCC 指标；
- SV1/SV2 对比、消融、CPU 复杂度和先验频率扫描；
- 移动激振器与悬臂梁的等价模拟代理、三档先验和频带边界扫描；
- 论文图5、8-20对应的信息结构图、表2-9对应CSV及五个模拟视频；
- 后续真实视频入口。

作者的激振器与悬臂梁原始视频、硬件和标定数据未包含在本目录中，因此这两组结果是
“等价模拟验证”，不是对论文真实实验本身的复现。完整的阶段性完成情况、结果分析、
未完成项、动态 ROI 接入和后续计划统一维护在
[BPAF_REPRODUCTION_COMPLETION_REPORT.md](BPAF_REPRODUCTION_COMPLETION_REPORT.md)。

## 运行环境

- MATLAB R2022b；
- Image Processing Toolbox；
- Signal Processing Toolbox；
- Global Optimization Toolbox；
- `third_party/matlabPyrTools`（已从用户指定位置复制到项目内）。
- `third_party/fdsst_sunjiajian`（仅作为 VP-DROI 动态 ROI 前置跟踪器，可回退到内置模板跟随）。

本机未安装 Parallel Computing Toolbox，正式运行使用 CPU。论文表4使用 RTX 3060 GPU，
因此本项目的耗时表只用于本机相对比较，不能与论文秒数直接对照。

## 一键运行

在 MATLAB 中运行：

```matlab
run('D:/LunFu/BPAF/scripts/run_all_reproduction.m')
```

再次运行会复用 `data/generated/` 和 `outputs/data/*_phase_features.mat` 缓存。
若需要重新生成数据或重新提取相位，在 `bpaf.default_config()` 返回的配置中将
`forceRegenerate` 或 `forceReextract` 设置为 `true`。

如果只需要按论文 4.2 节重新生成高分辨率小球视频，可运行：

```matlab
run('D:/LunFu/BPAF/scripts/generate_paper_sv_videos.m')
```

该入口输出 `outputs/videos/paper_sv/` 下的 SV1/SV2：960×540、1000 FPS、5 s、20 Hz 微振动，
并在 `data/generated/paper_sv/` 保存对应的米制位移真值。它不会覆盖原有的 90×160、200 FPS
CPU 代理视频；后者仍用于当前低成本全流程回归。

快速处理论文规格视频并输出测量区域、波形和频谱图：

```matlab
run('D:/LunFu/BPAF/scripts/process_paper_sv_videos.m')
```

该入口使用固定横向测量走廊 `x=1..960, y=210..330`，覆盖小球从左到右的整条轨迹，
不随小球移动；为了控制运行时间，处理时空间缩放为 0.5、时间步长为 4，等效采样率为
250 Hz。结果位于 `outputs/data/paper_sv_fast/` 和 `outputs/figures/paper_sv_processed_fast/`。

## 使用真实视频

独立的 BPAF 真实视频入口是 `scripts/run_real_data.m`。它使用 BPAF 自己的
`config.bpaf.motionScenario` 和 `config.bpaf.temporalReference` 语义，不依赖 MPME 的
`motionModel` 或 `referenceMode` 字段。只需修改脚本顶部的 `config.videoPath`、
`config.outputDirectory` 和 `config.bpaf.frequencyBandHz`，其余输入输出、ROI、帧率、最大
帧数和本次运行清理开关均已集中在同一配置区。`config.roi=[]` 时会在首帧手动框选；双击
或按 Enter 确认，Esc/关闭窗口会安全停止，不会触发 `wait(rectangleHandle)` 句柄错误。

真实视频默认使用 `config.dynamicROI.mode='trend'` 和
`config.dynamicROI.tracker='fdsst'`：先跟踪目标，再用物理时间窗提取宏观运动趋势，最后
移动固定尺寸的 BPAF 测量窗口，从而避免把微振动一起稳掉。fDSST 依赖不可用时会自动回退
到模板平移跟随。`searchRadiusPx` 应覆盖相邻帧最大位移；匹配/跟踪质量会写入轨迹 CSV。
若目标存在明显旋转、缩放、遮挡或单帧位移过大，应扩大初始 ROI/搜索半径，或使用当前
论文适用的几何跟踪器；也可将 `config.dynamicROI.mode='fixed'` 作为原论文 baseline。

结果按运行目录保存为 `01_bpaf_roi_selection.png`、`02_bpaf_roi_input.png`、
`03_bpaf_roi_tracking.mp4`、`03_bpaf_roi_trajectory.csv`、`04_bpaf_phase_features.mat`、
`05_bpaf_vibration_signal.csv`、`06_bpaf_run_result.mat` 和 `07_bpaf_paper_style_result.png`。
此外会单独输出 `08_bpaf_waveform.png/.fig` 与 `09_bpaf_spectrum.png/.fig`；其中 `.fig`
保留 MATLAB 图形对象，可重新编辑坐标、字体和曲线。`07` 总图仍然保留；`07`、`08`、`09` 均采用 BPAF 论文的
黑色主曲线、红色频带辅助线和 Times New Roman 英文标注，其中 `07` 保持四面板信息结构；不会套用 MPME
的输出样式。`scripts/run_user_video.m` 仍保留作为不需要交互 ROI 的简化入口。

对已经生成的真实视频结果，可直接运行：

```matlab
run('D:/LunFu/BPAF/scripts/export_existing_real_figures.m')
```

该脚本只读取已有 `06_bpaf_run_result.mat`，不会重新处理视频。

如需将真实视频结果与三角光 LDV 真值批量对比，可运行：

```matlab
run('D:/LunFu/BPAF/scripts/compare_real_data_truth.m')
```

脚本处理 `outputs/07-26_single` 和 `outputs/0819`，按输出视频名匹配
`E:/sanjiao/0726`、`E:/sanjiao/0819` 中的同名 CSV，并读取三角光第 3 列（100 Hz）。
由于三角光先于视频开始，脚本会自动估计非负时差；波形图使用去趋势归一化信号，频谱图
使用归一化幅值。每个匹配的视频目录下会生成 `comparison` 子目录，其中 BPAF 为黑色实线、
三角光 LDV 为红色虚线，并同时保存 PNG、FIG、指标 CSV 和对比数据 MAT。没有同名真值文件的
视频（当前为 `sun-3050-30mvpp`）会自动跳过。

`.fig` 是 MATLAB 的可编辑图形文件，不是普通图片格式。导出器现在会在写入 FIG 前将
Figure 的 `Visible` 固定为 `on`，因此文件加载后不会因为后台绘图状态而隐藏。当前机器的
`.fig` 关联命令仍只会启动 MATLAB 并切换到文件所在目录，没有把双击文件传给 `openfig`，
所以双击可能只启动 MATLAB 而不显示图形；这属于系统关联行为，不是导出文件损坏。可在
MATLAB 中执行：

```matlab
addpath('D:/LunFu/BPAF/scripts');
open_bpaf_fig('D:/LunFu/BPAF/outputs/07-26_single/kuai-qiao/08_bpaf_waveform.fig');
```

不提供路径时，`open_bpaf_fig` 会弹出文件选择框。也可以右键该 FIG 文件，选择“打开方式”
并关联 MATLAB。当前导出器使用兼容性更好的 `saveas(...,'fig')` 格式。

如果要为其他论文编写类似入口，请先阅读
[REAL_VIDEO_RUN_SCRIPT_REFERENCE.md](REAL_VIDEO_RUN_SCRIPT_REFERENCE.md)。该文档只统一
脚本的可读性、ROI 安全交互、输入输出留痕和错误处理原则；每篇论文的算法逻辑、参数
语义和图片风格仍必须独立设计。

真实视频需要明确帧率、运动方向、目标 ROI 与近似频率范围。当前默认方向带针对水平方向
位移；若实际振动方向不同，应先用已知运动或目视边缘方向核对 `orientationBand`。

## 目录

```text
BPAF/
  AGENTS.md
  README.md
  REPRODUCTION_REPORT.md
  deep-research-report.md
  Video-based subtle vibration measurement in the presence of large motions.pdf
  scripts/                 # 总入口与真实视频入口
  src/+bpaf/               # 核心 MATLAB 包
  third_party/matlabPyrTools/
  third_party/fdsst_sunjiajian/
  data/generated/          # 合成帧与真值
  experiments/EXPERIMENTS.md
  outputs/
    figures/               # 正式对照图
    tables/                # 指标 CSV
    videos/                # 合成/代理视频
    data/                  # 相位缓存与总结果 MAT
```

## 主要结果

- SV1/SV2：所有正式方法均识别到 20 Hz；PVE 的峰值为 0 Hz，表明大运动占主导；
- BPAF 先验上限 `FH=20:100 Hz`：两个仿真均为 81/81 次命中 20 Hz；
- 激振器代理：三档先验均为 30.75 Hz，真值 30.7 Hz；
- 悬臂梁代理：三档先验均为 5.333 Hz，真值 5.3 Hz；BPAF L1 的频谱 PCC 为 0.9872；
- 激振器所有包含 30.7 Hz 的扫描频带：18/18 次命中。

绝对 PER/RMSE 与论文表2不一致，且本代理数据上 BPAF 的 PER 未复现论文中始终优于三种
对比方法的排序。因此本项目只声明算法链和主频恢复成功，不声明数值表格与论文完全复刻。
