function cfg = config_default(projectRoot)
%CONFIG_DEFAULT Crossline-Phase 论文复现与真实视频的默认配置。
% 论文明确：每帧重新定位 crossline 中心，并用当前中心更新下一帧方形 ROI。
% 复现推断：分割、Hough 粗拟合和零相位等值线的具体离散实现。
if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end
cfg = struct();
cfg.projectRoot = projectRoot;
cfg.method.name = 'Crossline Phase Zero-Crossing';
cfg.method.roiSize = 128;
cfg.method.phaseOversampling = 4;
cfg.method.updateFilterEachFrame = true;
cfg.method.gaborPeriodFactor = 2.0;
cfg.method.sigmaCoverage = 6.0;
cfg.method.minValidLineSupport = 8;
cfg.method.phaseDiagnostics = false; % 仅主流程不生成整幅高分辨率 phase 诊断图，加速且不改变定位结果
cfg.method.useSeparableGabor = true;  % 当前各向同性 Gabor 可严格分离为两次一维卷积
% 以下参数属于复现推断：论文未给出代码级分割和形态学设置。
cfg.coarse.adaptiveSensitivity = 0.52;
cfg.coarse.minArea = 8;
cfg.coarse.closeRadius = 1;
cfg.coarse.houghPeakFraction = 0.25;
cfg.coarse.houghPeakCount = 20;
cfg.coarse.lineDistanceTolerance = 2.5;
cfg.coarse.brightMarkerThreshold = []; % 可选：白色标记/暗色物体测试时使用的强亮阈值
cfg.simulation.randomSeed = 20260902;
cfg.simulation.numTrials = 100;
cfg.simulation.beta1 = 400;
cfg.simulation.beta2 = 100;
cfg.simulation.sensorIntegrationSamples = 12;
cfg.simulation.imageSize = [128 128];
cfg.simulation.fx = 1800;
cfg.simulation.fy = 1800;
cfg.simulation.tz = 1000;
cfg.simulation.markerLengthMm = 35;
cfg.simulation.markerWidthMm = 2;
cfg.simulation.runTables = true;
cfg.simulation.runFigure6 = true;
cfg.simulation.fig6Frames = 1000;
cfg.real.videoPath = '';
cfg.real.outputName = 'crossline_real_video';
cfg.real.roi = [];
cfg.real.maxFrames = Inf;
cfg.real.fpsOverride = [];
cfg.real.writeTrackingVideo = false;
cfg.real.saveProcessImages = true;
cfg.real.fastMode = true; % 真实视频默认使用经过等价性验证的 phaseOversampling=2
cfg.real.rejectLargeJumps = true; % 按论文 ROI 捕获范围拒绝异常帧间跳变
cfg.real.maxFrameJumpPx = []; % [] 时取初始 ROI 边长的 1/4
cfg.real.useVelocityPrediction = false; % 可选实验项；默认保持论文的上一帧中心更新 ROI
cfg.real.expectedFrequenciesHz = []; % 可选：已知激励频率，用于生成局部频谱放大图
cfg.real.outputDirectory = fullfile(projectRoot, 'outputs', 'real_video');
cfg.output.root = fullfile(projectRoot, 'outputs');
cfg.output.clearPreviousResults = false;
cfg.output.figurePosition = [80 80 1100 760];
end
