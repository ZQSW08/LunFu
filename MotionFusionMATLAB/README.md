# MotionFusionMATLAB：运动物体的像素位移与相对振动测量

纯 MATLAB 工程，保留固定模板亚像素配准、亮条剖面测量和空间参考补偿。2026-09-07 增加自动多参考候选；原 `profile + anchor` 双 ROI 路径继续保留。需要 MATLAB R2022b、Image Processing Toolbox；可选频带/模态和激光评价需要 Signal Processing Toolbox。自动参考不需要 Computer Vision Toolbox。

## 选择入口

在 MATLAB 中先进入本目录，然后打开脚本修改顶部配置：

| 入口 | 用途 |
|---|---|
| `run_user_video.m` | 保留用户当前配置，默认双 ROI、原始测量 |
| `run_user_video_baseline.m` | 双 ROI 基线，额外生成旧版宽带/稳定模态诊断图 |
| `run_user_video_automatic.m` | 只框选目标，自动寻找多个参考小块；可填写同体粗搜索范围 |
| `run_user_video_auto(videoPath,outputRoot,targetROI,searchROI,overrides)` | 自动模式函数入口，便于批处理；searchROI 可为空 |
| `run_real_video(u)` | 完整函数入口，默认配置见 mfm.real_defaults() |

视频路径、输出目录和采集帧率均由用户配置；示例中的本机路径不代表仓库包含实验数据。`captureFPS` 是实际采集帧率，只有为空时才用视频文件元数据。`maxFrames=200` 只用于试运行；正式评价需完整视频。

`axis='x'/'y'` 按实际实验方向选择，不能按哪个方向出现理想频峰来选。`profile` 用于亮条，y 通过输入转置测量；正交坐标只是搜索引导。独立二维测量用 `targetMode='texture'; axis='xy'`。

## 目标与手动参考

ROI 使用第一帧 MATLAB 一基坐标 `[x y width height]`，宽高至少 12 像素。

- `roiMode='interactive'`：框选目标。
- `roiMode='manual'`：填写 targetROI。
- `roiMode='saved'`：从 roiSource 的 MAT 文件中只读 roi 字段。没有显式路径时按视频名定位本地 MPME 保存的几何，其他变量不会进入测量。

参考与目标独立配置。`referenceSelection='interactive'` 框选刚性参考，manual 使用 referenceROIs（每行一个框）。参考须共享目标宏观运动、且不含待测局部振动。translation 可以用一个参考；有旋转/尺度变化时使用 similarity 和至少两个分离参考。

## 自动参考

```matlab
u=mfm.real_defaults();
u.videoPath='path/to/video.avi';
u.outputRoot='path/to/local_outputs';
u.captureFPS=100;
u.roiMode='interactive';
u.referenceSelection='automatic';
u.referenceModel='translation';
u.searchROI=[]; % 全图；或同一运动部件的粗范围[x y w h]
r=run_real_video(u);
```

第一帧排除目标及邻近边缘，按两个方向的纹理梯度筛选小块，再兼顾纹理质量和空间分散程度选择默认 8 块。每帧独立跟踪这些固定模板，从候选位移中寻找多数一致的平移群；至少 3 块、足够支持比例、没有相近规模的竞争群、且群内离散程度满足门限才输出参考补偿。保存逐帧参考成员、支持数、离散程度和状态码。

**使用条件：多数候选必须属于与目标共享宏观运动的部件。** 全图里若有多个物体，优先填写粗略的 searchROI。自动模式当前只估计平移，不会自动识别哪个物体在物理上应当充当参考；一致运动也不能证明这些区域不含共同刚体振动。

首帧纹理不足会报 `mfm:MissingAutomaticReference`。运行中共识不足时相对位移留 NaN，同时保留仍能跟踪到的目标总位移；profile 的引导在参考缺测期间停留于最后有效值，因此长时间参考丢失也可能使目标失跟。`referenceModel='none'` 配空参考时测的是总位移，不能将其解释为已消除大运动。

## 输出与解释

输出自动追加视频文件名。通过 run_real_video 创建的同名旧结果带 .mfm_output 标记时移入 _history；不覆盖未标记目录。

- `result.mat`、`traces.csv`：总位移、参考位移、未滤波相对位移、逐帧有效性和匹配误差。自动模式增加参考共识诊断。
- `roi_provenance.json`、`01_first_frame_rois.png/.fig`：目标与参考坐标、来源；自动模式包含候选数及纹理分数。
- `02_waveform_x/y`、`03_spectrum_x/y`：原始测量波形/频谱，同时输出 CSV、PNG、FIG。无效帧保持原时间轴和 NaN；频谱使用最长连续段并报告时长与频率分辨率。
- `04_optional_filter_x/y`：仅在填写 analysisBandHz 后生成的额外诊断；denoise=true 启用视频证据筛选的稳定模态分量。它不替代原始测量，滤波后干净不等于原始精度提高。

所有 FIG 保存时 Visible='on'。showFigures=false 只在保存后关闭窗口。位移单位为 px；毫米振幅需要独立成像标定。参考和目标共享的真实刚体振动也会被扣除，因此测量量主要是相对于参考的局部运动。

## 回溯与验证

```matlab
test_audit_contracts;
test_upgrade;
test_auto_reference;
test_direction_and_speed; % 依赖本地历史合成视频
```

`run_round_baseline('唯一目录名')` 从本地归档 result.mat 中读取几何/设置重放八段视频，比较原始数组与缺测掩码。它依赖未上传的历史结果，属于历史复现工具；不是通用算法用视频名选择参数的入口。旧“乱动”配置包含两个参考、similarity、median 引导和 1400 个采样预算，不能与统一默认设置混作同一基线。

`run_auto_reference_validation` 运行自动参考测试；`run_round_automatic` 批量跑本地实拍。合成测试与已见实拍是开发验证，不等于新采集盲测。

激光只从独立后处理入口读入：

```matlab
compare_laser_v2(resultDirectory,laserPath,laserFPS,column);
```

该评价先用视频前半段拟合一次延迟、符号、比例，再比较后半段共同有效样本；所有视频已用于开发，因此这是留段诊断。拟合像素比例不是独立毫米标定，高相关不能证明绝对振幅准确。`run_round_laser_review` 会核对评价前后测量文件哈希。

## 每次修改前备份

在 PowerShell 中进入本目录，编辑已有主源码前运行：

```powershell
./backup_core.ps1 -Label describe_change
```

快照位于 backups/时间_原因/，manifest.json 保存原路径、修改时间、长度与 SHA-256，复制前后和副本均核验。回退前先备份当前状态，再只复制选定快照中的需要恢复的源码；不移动或删除输出数据。

仓库只保存核心源码、运行入口和使用说明。视频、激光数据、结果、图像、论文附件、备份及本地审计报告均不上传。各论文复现工程保持原代码，可选第三方依赖按各自说明另外安装。

固定模板逆组合配准依据 [Baker 与 Matthews 的 Lucas–Kanade 统一框架](https://publications.ri.cmu.edu/lucas-kanade-20-years-on-a-unifying-framework)。本工程的自动多参考组合属于待验证的工程改进，不宣称论文首创性。
