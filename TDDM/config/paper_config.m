function cfg = paper_config()
%PAPER_CONFIG TDDM 论文参数与 MATLAB 实现参数。
% 论文未明确给出的数值均放在 impl 节，避免把实现推断误写成论文设置。

cfg = struct();

%% 论文明确报告的参数
cfg.paper.nccGate = 0.60;
cfg.paper.eccentricityMax = 0.70;
cfg.paper.shiftStart = 0;
cfg.paper.shiftEnd = 1;
cfg.paper.shiftStep = 0.01;
cfg.paper.brightnessLevels = [33 127 250];
cfg.paper.noiseSigma = [0.01 0.03 0.05];
cfg.paper.blurLength = [2 5 10];
cfg.paper.rotationAngles = [5 15 30];
cfg.paper.vibrationFPS = 640;
cfg.paper.vibrationDuration = 6.4;
cfg.paper.vibrationResolution = [1600 526];
cfg.paper.pxPerMM = 1.6;
cfg.paper.rotationFPS = 500;
cfg.paper.rotationFrames = 120;
cfg.paper.rotorRPM = 530;
cfg.paper.rotationResolution = [1600 1600];
cfg.paper.templateSize = 37;
cfg.fusion.nccGate = cfg.paper.nccGate;
cfg.fusion.mode = 'coordinate_safe';

% 视频入口的进度配置；合成实验默认关闭，真实视频脚本会显式开启。
cfg.video.progressEveryFrames = 25;
cfg.video.showProgress = false;

%% MATLAB 复现实现参数（论文未明确）
cfg.impl.outputRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
cfg.impl.randomSeed = 7;
cfg.impl.useToolboxes = true;
cfg.impl.interpolation = 'cubic';
cfg.impl.icgnMaxIter = 50;
cfg.impl.icgnTolerance = 1e-4;
cfg.impl.icgnDamping = 1e-10;
% 默认用本地六参数接口保证 TDDM 全流程对异常初值的稳定性；ADIC2D
% 适配器仍可通过 cfg.impl.icgnEngine='adic2d' 显式启用并用于交叉验证。
cfg.impl.icgnEngine = 'native';
cfg.impl.icgnModel = 'affine';
cfg.impl.useZNNormalization = true;
cfg.impl.useForwardBackward = true;
cfg.impl.enableTracking = true;
cfg.impl.enableDetection = true;
cfg.impl.enableICGN = true;
cfg.impl.kltMaxCorners = 20;
cfg.impl.kltQualityLevel = 0.01;
cfg.impl.kltMinDistance = 3;
cfg.impl.kltBlockSize = 7;
cfg.impl.kltMaxBidirectionalError = 1.0;
cfg.impl.kltNumPyramidLevels = 4;
cfg.impl.detectorUseCLAHE = true;
cfg.impl.detectorMode = 'circle';
cfg.impl.detectorMinArea = 10;
cfg.impl.detectorDiameterRatio = [0.60 1.60];
cfg.impl.realMarkerDiameterPx = 8;
cfg.impl.roiWindowFactor = 3.0;
cfg.impl.syntheticImageSize = [256 256];
cfg.impl.syntheticMarkerDiameter = 24;
cfg.impl.syntheticCanvasMargin = 45;
cfg.impl.syntheticNoiseSeed = 7;
cfg.impl.saveProcess = false;
cfg.impl.processFrames = [1 2];
cfg.impl.processOutputRoot = fullfile(cfg.impl.outputRoot, 'process');
cfg.impl.proxyVibrationFrames = 4096;
cfg.impl.proxyVibrationImageSize = [256 256];
cfg.impl.proxyRotationImageSize = [512 512];
cfg.impl.proxyRotationMarkers = 3;
cfg.impl.proxySaveFrames = false;

%% 默认开关
cfg.run.synthetic = true;
cfg.run.vibration = true;
cfg.run.rotation = true;
cfg.run.ablation = true;
cfg.run.saveFigures = true;
cfg.run.visibleFigures = false;
end
