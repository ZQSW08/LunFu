# LoG-Gabor 论文复现

本目录只服务于论文：**Full-field phase-based vibration measurement and visualisation using many knowledge transfer-assisted optimal log-Gabor filters**（Mechanical Systems and Signal Processing 225, 2025, Article 112256）。总项目根目录下的其他论文复现不得把代码或输出放入这里。

## 运行

在 MATLAB R2022b 中执行：

```matlab
cd('D:/LunFu/LoG-Gabor')
addpath('scripts')
summary = run_reproduce;
```

入口脚本会依次运行 Fourier 亚像素合成、Log-Gabor/PME、Table 1 风格参数扫描、单任务 GA baseline、3×3 task mapping、active-pixel mask、MMD/AMP/GA-EDA MaTO、全场位移和 instantaneous/frequency ODS，并生成 steel/cable/SSRM 的等价模拟结果。

## 目录

- `src/`：论文方法的可复用 MATLAB 函数。
- `scripts/run_reproduce.m`：唯一主入口。
- `configs/default_config.m`：论文参数与实现推断参数的集中配置。
- `outputs/process/`：合成视频、active mask 和算法链中间结果。
- `outputs/figures/`：正式过程/ODS 图。
- `outputs/videos/`：等价模拟视频。
- `outputs/tables/`：参数扫描、钢板代表性 ROI 和运行汇总。
- `experiments/EXPERIMENTS.md`：长期实验账本。
- `third_party/matlabPyrTools/`：用户提供并复制到本论文目录的工具箱；当前核心路径不强制依赖其 steerable-pyramid 接口。

## 论文图组与中间输出

主入口会按论文方法顺序生成可检查的中间量，而不是只保存最终位移图：

- Fig. 1：`outputs/process/fig1_filter_responses.png`，输入图、频域、局部振幅、局部相位和 Table 1 风格的五组滤波器。
- Fig. 2–4：`fig2_single_target_flow.png`、`fig3_fullfield_process.png`、`fig4_task_mapping.png`，分别对应单点 PME、全场处理链和 3×3 task mapping。
- Fig. 5/23：`cable_active_pixels.png`、`ssrm_active_pixels.png`，保存局部振幅、填充区域和 active-pixel mask；cable 使用填充区域策略，SSRM 使用论文描述的边缘策略。
- PME 中间量：`representative_pme_intermediates.png` 及 `cable_representative_intermediates.mat`，包含原始相位、包裹相位差、展开相位差、单帧增量、累积位移和振幅。
- Fig. 14–15：`fig14_mmd_values.png`、`fig15_mato_ipso_comparison.png`，以及 `cable_equivalent_result.mat` 中的 `mmdMatrix`、`ampHistory`、`similarHistory`。
- Fig. 17/19–21：cable 的时域、ROI 时频/FFT、瞬时 ODS 和频率 ODS；瞬时 ODS 只以彩色显示 active 像素，无效区域保留为浅灰背景。
- Fig. 24–25：`fig24_25_ssrm_comparison.png`，并另存 `ssrm_frequency_ods.png`。

文件名中的 `equivalent` 表示等价模拟实验：由于当前目录没有论文作者的原始视频、LDV 和加速度计同步数据，不能宣称数值上 exact reproduction。替换为真实数据后，应保留同样的中间量和图组输出。

## 忠实性边界

论文明确给出了 Log-Gabor 公式、PME 关系、3×3 任务映射、局部振幅/形态学填充、MMD、AMP、GA/EDA 和 25/250 Hz 等实验条件。原文没有完整公开中心频率映射、优化边界、MMD 的 `sigma/l`、EDA 聚类细节及全部传感器同步处理，因此这些值在配置中标为“实现推断”。

项目中没有论文作者的原始视频、LDV 或加速度计数据；因此 steel、cable、SSRM 是保留论文科学问题和采样条件的等价模拟，不是原始数据的 exact numerical reproduction。替换 `data/` 中的真实数据后，可沿用同一入口中的 PME、全场和 ODS 模块继续处理。
