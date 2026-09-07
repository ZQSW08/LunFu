function cfg = default_config(projectRoot)
% DEFAULT_CONFIG 返回 MP-G2LPT 的默认配置。
% 论文/报告明确：首帧 anchor、多尺度、多方向、全局粗定位到局部相位匹配。
% 下面未由参考材料明确给出的阈值，均属于“实现推断”，集中放置便于复现实验。

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

cfg = struct();
cfg.projectRoot = projectRoot;
cfg.method = struct();
cfg.method.name = 'MP-G2LPT';
cfg.method.referenceFrame = 'first';             % 首帧 immutable anchor
cfg.method.observedAxis = 'both';                % 观测方向：'x' 水平、'y' 垂直；'both' 为二维
cfg.method.maxPocJumpPx = 150;                   % 实现推断：POC 单帧异常大跳变保护
cfg.method.predictionEnabled = true;             % V3：健康跟踪时使用一阶速度预测
cfg.method.predictionHorizon = 1.0;               % V3：预测下一帧的时间步长
cfg.method.maxPredictionResidualPx = 4.0;         % V3：预测搜索偏差过大时不更新轨迹/模板
cfg.method.recoveryAfterLostFrames = 2;          % V3：连续失效后才启用 POC 恢复
cfg.method.recoveryMinPocPeakScore = 0.08;        % V3：POC 恢复最低峰值可信度
cfg.method.recoveryMinPocPeakRatio = 0.01;        % V3：POC 恢复最低峰值间隔
cfg.method.templateBankEnabled = true;            % V3：允许安全更新 recent/best 模板
cfg.method.templateUpdateMinQuality = 0.55;       % V3：只有高质量帧允许更新模板
cfg.method.templateUpdateIntervalFrames = 5;      % V3：限制 recent 模板更新频率
cfg.method.templateMaxAgeFrames = 30;             % V3：recent 过期后回退 best/anchor
cfg.method.templateUpdateMinPeakRatio = 0.03;     % V3：模板更新所需的峰值间隔
cfg.method.templateUpdateMinAgreement = 0.50;     % V3：模板更新所需的跨尺度一致性
cfg.method.minValidRateForDecomposition = 0.20;   % 低于此比例不输出伪造的 V2 分解结果
cfg.method.orientationsDeg = [0 45 90 135];      % 报告建议的四个方向
cfg.method.wavelengthsPx = [24 15 9];             % 实现推断：粗到细、避免整数谐波重合
cfg.method.gabor.sigmaAlongRatio = 0.60;
cfg.method.gabor.sigmaAcrossRatio = 0.35;
cfg.method.gabor.supportSigma = 3.0;
cfg.method.minAmplitudeFraction = 0.12;
cfg.method.localSearchRadiusPx = 12;
cfg.method.subpixelMaxPx = 1.5;
cfg.method.phaseMeanSigmaRad = 0.45;
cfg.method.minTrackingQuality = 0.12;
cfg.method.singleScaleIndex = 2;
cfg.method.useAmplitudeWeight = true;
cfg.method.trackingScaleIndices = 1:numel(cfg.method.wavelengthsPx);
cfg.method.measurementScaleIndices = 1:numel(cfg.method.wavelengthsPx);
cfg.method.measurementOrientationIndices = 1:numel(cfg.method.orientationsDeg);

cfg.decomposition = struct();
cfg.decomposition.mode = 'band_protected';   % temporal / band_protected / spatial
cfg.decomposition.temporalCutoffHz = 2.0;    % 实现推断：宏观跟随器截止频率
cfg.decomposition.vibrationBandHz = [2 30];  % 实现推断：需要保护的振动频带
cfg.decomposition.minSpatialConsensus = 3;

cfg.output = struct();
cfg.output.writeTrackingVideo = true;
cfg.output.figureVisible = 'off';
cfg.output.videoFrameRate = [];
cfg.output.saveIntermediate = true;
cfg.output.directory = fullfile(projectRoot,'outputs','real_data','real_video');
cfg.output.clearPreviousResults = true;

cfg.video = struct();
cfg.video.path = '';
cfg.video.maxFrames = Inf;
cfg.video.fpsOverride = [];
cfg.video.roi = [];
cfg.video.processingScale = 1;
cfg.video.progressEveryFrames = 25;

cfg.plot = struct();
cfg.plot.fontName = 'Times New Roman';
cfg.plot.fontSize = 10;
cfg.plot.blue = [0.0000 0.4470 0.7410];
cfg.plot.red = [0.8500 0.3250 0.0980];
cfg.plot.gray = [0.35 0.35 0.35];
end
