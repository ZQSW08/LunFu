# AP-CV 论文复现

本项目复现 Ma 等人在 *Mechanical Systems and Signal Processing* 发表的论文：

> Computer vision-based cross-scale structural displacement estimation using amplitude-phase fusion

## 当前复现范围

已经实现论文公式 (14)-(26) 对应的完整 MATLAB baseline：

1. 使用复数可转向金字塔高通残差的幅度行剖面进行整数像素互相关粗配准；
2. 按粗位移对当前帧进行空间对齐；
3. 从指定层级和方向子带提取局部相位，计算亚像素残差；
4. 使用逐像素时间相位相关系数与 Otsu 阈值自动选择主动像素；
5. 根据相邻金字塔层的线性关系自动选择层级；
6. 通过每帧上下移动 `+1/-1` 像素自动标定相位到像素尺度；
7. 融合整数粗位移和相位亚像素位移，并换算为物理位移；
8. 复现幅度-only、未标定平均相位、全像素、幅度阈值主动像素和不同金字塔层级对照。

作者原始相机视频和 LDV 真值在论文中标注为“可申请获取”，当前目录未包含这些数据。因此，论文中的 5 组单层建筑实验、8 组人行桥实验以及图 6-18 均采用带已知真值的**等价合成复现**。这些结果验证算法链，不能表述为作者真实实验的逐数据复现。

## 运行

环境：MATLAB R2022b，Image Processing Toolbox、Signal Processing Toolbox、Statistics and Machine Learning Toolbox。

在 MATLAB 中运行：

```matlab
run('D:/LunFu/AP-CV/scripts/run_all_reproduction.m')
```

真实视频入口为 `scripts/run_real_video.m`。打开该脚本顶部的用户配置，填写 `videoPath`；`roi=[]` 时在首帧直接拖动框选固定区域，也可以填写 `[x y width height]`。`method.direction` 填写 `x` 或 `y`，分别分析 X/Y 方向一维振动（当前默认 `x`）；`gammaMmPerPixel` 留空时只输出 pixel，填写正值后才输出 mm；`truthPath` 只有在提供同步真值 CSV 时才会计算 RMSE/PCC。入口记录原始/处理帧率、实际帧数和帧索引，并把运行结果写入 `outputs/real_data/`。当前入口只实现论文中的固定首帧参考和一维平移，不自动加入动态 ROI 或其他论文的运动模型。

默认配置位于 `configs/apcv_default_config.m`。随机种子固定为 `20260828`。默认使用 `128 x 160` ROI、29.97 Hz、每场景 180 帧；这是为了在普通电脑上完整运行全部实验，不是论文原始的 3840 x 2160 视频尺寸或 1800 帧标定规模。

坐标约定：X 方向图像向右为正，Y 方向图像向下为正。由于所选方向滤波器的相位符号，自动标定的 `s` 为负数；其与相位差相乘后得到正确的正向像素位移。

## 结果

固定配置下的完整运行用时约 82 秒：

| 等价实验 | 融合平均 RMSE | 幅度-only 平均 RMSE | 未标定相位平均 RMSE | 自动层级 |
|---|---:|---:|---:|---:|
| 单层建筑，5 场景 | 0.0491 mm | 0.9121 mm | 0.3208 mm | 2 |
| 人行桥，8 场景 | 0.0077 mm | 0.3685 mm | 0.1041 mm | 2 |

合成图像比真实现场数据更规整，所以上述误差小于论文真实实验报告值并不代表实际性能更高。

主要输出：

- `outputs/figures/`：图 6、9、11-15、17-18 的 PNG 和矢量 PDF；
- `outputs/process/`：图 7、8、10、16 的过程图；
- 真实视频运行目录：中间过程图、位移波形 PNG/FIG、单边幅值频谱 PNG/FIG，以及 CSV/MAT 结果；真实视频入口不输出 PDF；
- `outputs/videos/`：实验室和桥梁代表性合成输入视频；
- `outputs/data/lab_metrics.csv`、`bridge_metrics.csv`：全部定量指标；
- `outputs/data/reproduction_results.mat`：真值、估计曲线、标定模型和配置。

## 代码结构

```text
AP-CV/
  configs/       统一参数
  scripts/       一键入口
  src/           算法、合成实验、指标和绘图函数
  third_party/   用户提供的 matlabPyrTools
  experiments/   唯一长期实验账本
  outputs/       正式数据、图和视频
```

`third_party/matlabPyrTools` 原样复制自用户提供路径，其 `pointOp.c` 已在本机编译为 `pointOp.mexw64`。在不兼容的平台上可重新编译；未编译时工具箱会退回较慢的 MATLAB 实现。

## 真实实验继续条件

获得作者或用户提供的视频、ROI、物理像素尺度和同步 LDV 数据后，只需将合成序列生成部分替换为真实视频读取，标定与估计主链无需改写。届时才能对论文报告的 0.2 mm/0.08 mm 真实实验结论进行严格复核。
