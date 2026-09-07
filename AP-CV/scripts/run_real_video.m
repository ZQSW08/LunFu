%RUN_REAL_VIDEO 使用 AP-CV 论文方法处理一个真实视频。
% 本脚本是用户入口：负责输入、ROI、运行参数和输出目录配置。
% 实际处理和文件写入分别在 src/apcv_run_real_video.m 与
% src/apcv_write_real_results.m 中完成，避免入口脚本复制一套算法代码。
% 运行前只需修改“用户配置”区域；原始视频始终只读。

close all; clearvars; clc;
scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));

% 加载工程函数、默认配置和第三方复数金字塔工具。
% configs 路径是必须的，因为默认参数函数位于 configs/apcv_default_config.m。
addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'configs'));
addpath(genpath(fullfile(projectRoot, 'third_party', 'matlabPyrTools')));

%% 用户配置：只修改本节，其他代码无需改动
runConfig.projectRoot = projectRoot;

runConfig.videoPath = 'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-1-t.mp4';
runConfig.outputDirectory = 'D:\LunFu\AP-CV\outputs\风洞项目\xinjiasuduji\2-33-1-t';% clearPreviousResults=false 时会在此目录下自动建立 run_时间戳 子目录。
runConfig.outputName = '2-33-1-t';  % 输出文件名前缀，
runConfig.roi = [];                 % 固定区域格式为 [x y width height]，% 留空 [] 会显示视频首帧，直接拖动鼠标框选；双击或按 Enter 确认，Esc/关闭取消。
runConfig.maxFrames = [];         % 最多处理帧数。减小它可快速试跑并降低内存占用；[] 表示读取视频的全部可用帧。
runConfig.fpsOverride = [];          % 兼容旧配置；填写 captureFps 后不再降采样，算法按每个可读取帧处理。
runConfig.captureFps = 200;            % 相机采集帧率（Hz）；例如相机真实采集为 100 Hz 就填写 100
runConfig.timeWindow.startSeconds = 0;      % 从采集时间轴的第几秒开始处理；由 captureFps 换算，不写死 100 Hz。
runConfig.timeWindow.durationSeconds = Inf; % 处理时长（秒）；例如 3.5 表示从 startSeconds 起处理 3.5 秒，Inf 表示直到视频结束。
% captureFps 同时定义算法 processingFps 和“采集时间轴”；文件的 VideoReader.FrameRate
% 只记录存储 metadata。若存储时确实丢帧，软件无法凭空恢复缺失的采集帧。
runConfig.gammaMmPerPixel = [];     % 物理尺度（mm/pixel）。[] 时只输出 pixel；填写正值后增加 mm 列和毫米曲线。
runConfig.writeTrackingVideo = false;% 调试逐帧检查时改为 true；会增加运行时间和磁盘占用。
runConfig.writeTrackingDiagnostics = false; % 按需输出 RMPTF 逐帧诊断图/CSV。
runConfig.verbose = true;           % true 显示金字塔、标定和估计过程信息；false 仅显示简要完成信息。

%% 可选：通用振动保持型动态 ROI（默认关闭，保持固定 ROI baseline）
% 开启后先用 fDSST 追踪目标（可改为 KLT 对照），黄色目标框裁剪后进入 AP-CV；
% 同时计算低频趋势用于诊断。微振动残差仍由 AP-CV 的幅值--相位方法测量。
% 这部分是 AP-CV 的前置追踪层，不替换论文测量算法。目标离开初始视野、
% 遮挡严重或 ROI 内纹理不足时会给出明确错误/边界标志。
runConfig.dynamicROI.enabled = false;       % true 启用长程前端；false 使用固定首帧 ROI baseline。
runConfig.dynamicROI.trackerType = 'rmptf'; % 单遍 RMPTF hybrid；需 fDSST 时显式改为 rmptf_fdsst。
runConfig.dynamicROI.mode = 'adaptive_macro'; % 趋势+大偏差宏观重居中，亚像素残差继续交给 AP-CV。
runConfig.dynamicROI.phaseCrosslineEnabled = false;
runConfig.dynamicROI.adaptivePyramidEnabled = true; % 跟踪不确定时选择更粗层；固定层结果仍保留
runConfig.dynamicROI.trackingAxis = 'x';   % 'x'、'y' 或 'xy'，只抑制指定方向的大运动。
runConfig.dynamicROI.largeMotionCutoffHz = 1.0; % 大运动低通截止频率（Hz）。降低=保留更慢趋势，微振动保留更多；提高=跟随更快但可能削弱低频振动。
runConfig.dynamicROI.maximumPoints = 160;    % KLT 首帧最多特征点；增大可提高鲁棒性但增加计算量。
runConfig.dynamicROI.minimumPoints = 6;      % 每帧至少有效点数；增大更严格，减小可容忍低纹理但误跟踪风险上升。
runConfig.dynamicROI.redetectPointCount = 15;% 有效点低于此值时在当前 ROI 重新检测。
runConfig.dynamicROI.redetectInterval = 20;  % 每隔多少原始帧重检测一次；更小更稳但更慢。
runConfig.dynamicROI.maximumStepPixels = 120; % 单帧最大跟踪步长；过小会限制大运动，过大可能接受误匹配。
runConfig.dynamicROI.fallbackVelocityDecay = 0.75; % 短时丢点时速度衰减预测系数；越小越快回到静止。
% fDSST 原始接口暂不提供 response confidence，dynamic_roi.csv 中 quality 会标记为 1，
% 真实可信度请结合尺度轨迹、触边标志和输出波形人工复核。

%% 可选同步真值配置
runConfig.truthPath = '';
% 没有同步参考传感器数据时保持为空，不会计算 RMSE/PCC。
runConfig.truthTimeColumn = 'time_s';
% 真值 CSV 的时间列名称，单位必须是秒且严格递增。
runConfig.truthDisplacementColumn = 'displacement_mm';
% 真值 CSV 的位移列名称。
runConfig.truthUnits = 'mm';
% 只能填写 'mm' 或 'pixel'；选择 mm 时必须同时填写 gammaMmPerPixel。

%% AP-CV 方法配置：固定首帧参考和一维平移
runConfig.method.direction = 'y'; % 位移方向：'x' 'y' 表示 X Y 轴（图像水平向右为正 x 图像向下为正y）。
runConfig.method.referenceFrame = 'first';% 参考帧固定为第一帧。
runConfig.method.pyramidHeight = 4;% 复数可转向金字塔层数。增大可覆盖更大粗位移，但计算量增加，且小 ROI 会自动降低层数。
runConfig.method.pyramidOrder = 3;
% 方向子带阶数；3 对应 4 个方向。改变会改变滤波器组和相位响应，需要重新验证。
runConfig.method.orientationBand = 2;
% 使用的方向子带编号（从 1 开始）。4 方向金字塔中，本入口对 X 方向默认用第 2 带，
% 对 Y 方向通常改用第 3 带；改动可能影响信噪比和相位符号，需用已知真值重新验证。
runConfig.method.maxCoarseLag = 34;
% 粗配准搜索的最大整数像素滞后。增大可处理更大位移，但计算量和误匹配风险也会增加。
runConfig.method.calibrationMaxFrames = 90;
% 相位-像素尺度标定最多使用的帧数。增大通常更稳定但更慢；应包含足够运动信息。
runConfig.method.roiOverflowPolicy = 'warn';
% 目标位移达到框选区域边长的比例时的处理方式：'warn' 提示、'error' 中止、'ignore' 忽略。
% 这不是目标分割算法；固定 ROI 无法恢复已经移出画面的目标。
runConfig.method.roiOverflowFraction = 0.40;
% 风险阈值，默认 0.40（40%）。降低可更早提醒，增大可减少提示但更容易漏掉越界风险。

%% 输出策略
runConfig.output.clearPreviousResults = true;
% false：保留旧结果并创建时间戳子目录；true：ROI 确认后清空指定目录，请谨慎使用。

%% 执行
% apcv_run_real_video 内部依次完成：读取视频、裁剪固定区域、构建金字塔、粗配准、
% 相位估计、主动像素选择、尺度标定、波形/频谱/过程图生成和结果文件写入。
try
    output = apcv_run_real_video(runConfig);
    if output.cancelled
        fprintf('未确认框选区域，已取消运行，原有输出未修改。\n');
        return;
    end
    fprintf('处理完成，结果已保存到：%s\n', output.outputDirectory);
    % 输出文件由 apcv_run_real_video/apcv_write_real_results 生成：
    %   *_displacement.csv  位移时间序列（pixel；有尺度时附 mm）
    %   *_run.mat           配置、视频信息、标定模型、结果和真值
    %   *_process.png       中间过程图（首帧、对齐、主动像素和标定响应）
    %   *_waveform.png/fig  位移波形图（PNG 和 MATLAB 可编辑 FIG）
    %   *_spectrum.png/fig  单边幅值频谱图（PNG 和 MATLAB 可编辑 FIG）
    %   *_dynamic_roi.csv/png（仅 dynamicROI.enabled=true）：带符号原始轨迹、
    %       低频大运动、微振动候选、实际裁剪窗口和追踪质量/触边标志
    %   *_tracking.avi      可选的原始视频画面叠加追踪框/分析 ROI/位移读数 AVI
    %   *_run.mat           同时保存 timeWindow、实际 source frame index 和 processingFps
catch ME
    fprintf(2, 'AP-CV 真实视频运行失败：%s\n', ME.message);
    rethrow(ME);
end
