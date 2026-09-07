# Crossline Phase 论文复现工程

本文件夹是 `Phase-based crossline center detection for robust vibration monitoring under large motion and pose variations` 的独立 MATLAB 工程。工程不调用 MPME、BPAF、AP-CV、PNL、DSST 或其他跨论文跟踪器。

## 运行入口

1. 在 MATLAB 中将当前目录切换到 `Crossline_Phase`。
2. 运行 `scripts/run_reproduction`，生成 S0、S3、Table 1–4 和 Fig. 6 的复现结果。
3. 打开 `scripts/run_real_video.m`，只修改顶部 `cfg.real.videoPath` 等用户配置，然后运行 `scripts/run_real_video`。
4. 真实视频首帧 ROI 支持拖动，双击或按 Enter 确认，按 Esc 取消并退出。
5. 没有现成视频时，运行 `scripts/generate_demo_videos`，视频会写入 `outputs/demo_videos`，可直接用于真实视频脚本测试。
6. 运行 `scripts/generate_motion_test_videos` 可生成 100 fps、10 s、1000 帧的大运动测试视频；配套用 `scripts/evaluate_motion_test_results` 与保存的真值比较误差。
7. 运行 `scripts/generate_object_motion_videos` 可生成带圆盘轮毂、机械臂和螺栓细节的物体视频，并测试光照、模糊和高速旋转。
8. 运行 `scripts/run_object_motion_batch` 可用生成器保存的推荐 ROI 批量处理四类物体视频；结果写入 `outputs/object_motion_results_final128`，再运行 `scripts/evaluate_object_motion_batch` 进行定量比较。
9. 运行 `scripts/analyze_object_error` 可分解有效定位误差、帧间跳变门控拒绝和检测失败，并生成误差诊断 PNG/FIG/CSV。

## 方法边界

论文明确的核心链路是：当前 ROI 内分割 crossline → 测量线宽/长度/方向及粗中心 → 为两条线建立复 Gabor → 相位提取 → 选择最接近粗中心的 phase zero-crossing → 两条线求交 → 用当前中心更新下一帧 ROI。

论文没有公开完整相机内参、原始 MATLAB 代码和可下载实验数据。本工程的高分辨率 marker、单应成像和分割/Hough/等值线离散细节均在代码注释中标为“复现推断”；Table/Fig.6 属于等价 pixel-wise 成像验证，不能表述为作者原始数据的逐数值复现。

## 输出

论文复现结果写入 `outputs/paper_reproduction`；真实视频每次运行写入带时间戳的新目录。真实视频至少保存 `crossline_trajectory.csv`、`crossline_results.mat`、波形 PNG/FIG 和频谱 PNG/FIG。MATLAB FIG 保存前固定设置 `Visible='on'`。

## 模拟视频

`generate_demo_videos` 会生成三种 AVI：清晰亚像素振动、大范围平移/旋转、含噪声振动。视频内置的十字标记用于验证本方法的完整处理链路；真实视频若没有清晰的十字标记，不能直接用本方法保证定位成功。

`generate_motion_test_videos` 另外生成水平线性大运动（0.8 Hz）和水平非线性复合大运动（0.55 Hz、1.35 Hz），两者均叠加 23 Hz 微振动。每个视频的 `*_truth.mat` 和 `*_truth.csv` 保存了逐帧真值。

真实视频默认启用 `cfg.real.fastMode=true`：Gabor 可分离卷积与零相位搜索优化均不改变核心公式；相位过采样从 4 改为 2。工程测试中同一帧中心差异小于 0.009 pixel，运行速度约提升到原来的 5–7 倍。关闭该选项即可回到 `phaseOversampling=4`。

真实视频还默认启用 `rejectLargeJumps=true`，超过初始 ROI 边长四分之一的帧间跳变会被标记为无效，并保留上一帧 ROI 中心，防止一次误检污染后续帧。该门限依据论文给出的 ROI 捕获范围，不对有效轨迹进行平滑。

每次真实视频运行目录都会自动生成 `README.txt`，其中说明 `crossline_waveform.png/.fig` 和 `crossline_spectrum.png/.fig` 的具体用途。总输出索引见 `outputs/RESULT_INDEX.md`。FIG 保存时统一为 `Visible='on'`，工程不保存 PDF。

已有结果若需要按最新绘图规范刷新，可运行 `scripts/refresh_result_plots(resultRoot)`；该脚本只重建图和频谱 MAT，不重新处理视频轨迹。
