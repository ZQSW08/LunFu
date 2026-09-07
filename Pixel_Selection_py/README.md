# Pixel_Selection：论文复现工程

论文：*Video-based structural vibration frequency measurement with reliability evaluation under camera disturbance*。

本目录是独立论文项目。总项目目录 `D:\LunFu` 下以后增加其他论文时，应使用各自的子目录；本项目的代码、依赖拷贝、数据和输出均限定在 `D:\LunFu\Pixel_Selection`。

完整复现说明见 [`REPRODUCTION_REPORT.md`](D:/LunFu/Pixel_Selection/REPRODUCTION_REPORT.md)。

## 当前可复现范围

论文正文明确给出的主链已经实现：

1. 复杂可转向金字塔（CSP）相位特征与相对第一帧的相位差；
2. 多帧相位差前景累积和最大连通域保留；
3. MEI、SAM、PSE 三种空间特征；
4. 经验 Bayes 似然比 / sigmoid / 平均池化的可靠像素选择；
5. 一阶时间差分、STD/range、稳健 Z 分数和异常窗口掩膜；
6. 0.1--50 Hz、0.01 Hz 网格的正弦字典与 FISTA L1 稀疏重构；
7. PF、FE、PER、RMSE、PCC 指标；
8. 论文 M1--M4 消融配置的等价软件验证。

当前目录没有论文真实 exciter 视频、shaking-table 视频和加速度计同步数据；论文数据声明为“按请求提供”。因此本次正式运行使用合成等价视频验证算法链，结果不能表述为真实硬件实验复现。PVE、STVSA、PMD 在本文中只有比较结果，没有足够的完整算法/参数定义，且没有作者代码，因此未用自定义代码冒充这些基线。

## 运行

```powershell
python scripts/run_reproduction.py --output-root outputs --frames 300
```

当前运行环境中已有所需 Python 库：`numpy`、`scipy`、`opencv-python`、`pyrtools`、`scikit-learn`、`matplotlib`。主入口是 `scripts/run_reproduction.py`，核心模块位于 `src/pixel_selection/`。

输出包括：

- `outputs/reproduction_results.json`：参数、指标、消融和限制；
- `outputs/data/intermediate_outputs.npz`：相位差、加权响应、前景候选/union/Cmax、MEI/SAM/PSE、三张置信图、融合置信图、可靠像素、时间窗口统计、掩膜序列、稀疏系数和 FFT 输入；
- `outputs/figures/`：按论文布局重绘的 Fig.1、2、3、4、5、7、8、9、10、11、14、16 等对应图；
- `outputs/process/`：逐帧相位差、加权响应、前景阈值/union、MEI/SAM/PSE、CM/CS/CP/Cf、时间信号、Z-score、掩膜和稀疏系数过程图；
- `outputs/videos/synthetic_case.mp4`：合成验证视频；
- `outputs/data/synthetic_case.npz`：视频、真值振动和相机扰动轨迹。

论文中 Fig.5/6/12/13/15/17 依赖真实 exciter 或 shaking-table 场景、设备照片、KLT 背景轨迹及加速度计数据；这些输入没有提供，因此没有生成伪造的“真实实验图”。本项目生成的 Fig.7/8/9/10/11/14/16 均明确标注为 synthetic equivalent 或 synthetic，图中蓝线/红虚线遵循论文的 proposed/ground-truth 视觉语义。

## 实现推断

论文没有完整公开 CSP 三类可靠性特征的类条件分布、时间窗口长度、阈值百分位的固定值及部分 FISTA 细节。代码中采用的推断值集中在 `src/pixel_selection/` 的中文注释中，并在 `reproduction_results.json` 中列出。论文明确给出的正则化参数 0.01、频率范围 0.1--50 Hz 和 0.01 Hz 步长保留为默认设置。

## MATLAB 资源

用户提供的 `matlabPyrTools` 已复制到 `third_party/matlabPyrTools/`，原始文件未修改。当前机器没有 MATLAB/Octave，故本次运行入口使用 Python；后续获得 MATLAB 环境后，可用该目录对 CSP 子带结果做交叉核对。
