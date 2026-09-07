function cfg = default_config()
%DEFAULT_CONFIG RMPTF 公共前端的默认配置。
% 本模块是论文后端之外的研究扩展：只负责目标可观测性与测量坐标管理，
% 不修改 M-PME、BPAF 或 AP-CV 的相位测量公式。

cfg.tracker.searchRadiusPx = 80;
cfg.tracker.backend = 'hybrid'; % hybrid / fdsst_improved
cfg.tracker.fdsstRoot = '';
cfg.tracker.allowBackendFallback = true;
cfg.tracker.useSafeMatlabFeatures = true;
cfg.tracker.redetectRadiusPx = 180;
cfg.tracker.maxStepPixels = 120;
cfg.tracker.scaleFactors = [0.94 1 1.06];
cfg.tracker.goodQuality = 0.58;
cfg.tracker.weakQuality = 0.34;
cfg.tracker.updateQuality = 0.72;
cfg.tracker.updateInterval = 5;
cfg.tracker.predictFrames = 4;
cfg.tracker.globalRedetectAfter = 8;
cfg.tracker.minimumNcc = 0.18;
cfg.tracker.anchorMinimumNcc = 0.12;
cfg.tracker.velocitySmoothing = 0.65;
cfg.tracker.usePhaseCorrelation = true;
cfg.tracker.useTemplateLocalization = true;
cfg.tracker.phaseCorrelationWeight = 0.15;
cfg.tracker.conservativeUpdate = true;
cfg.tracker.useTemplateBank = false; % 三模板 NCC 每帧约 3x；丢失恢复仍保留 anchor/best 全局重检测
cfg.tracker.enableRedetection = true;
cfg.tracker.slowLearningRate = 0.25;
cfg.tracker.recoveryConfirmFrames = 2;
cfg.tracker.maximumBlurDrop = 0.55;

cfg.roi.dualEnabled = true;
cfg.roi.trackingExpansion = 1.7;
cfg.roi.analysisPadding = 0.30;

cfg.klt.enabled = true;
cfg.klt.maximumPoints = 160;
cfg.klt.minimumPoints = 6;
cfg.klt.minimumQuality = 0.005;
cfg.klt.maximumBidirectionalError = 2;
cfg.klt.ransacMaxDistance = 2.5;

cfg.phaseCrossline.enabled = false;
cfg.phaseCrossline.wavelength = 10;
cfg.phaseCrossline.sigma = 4.5;
cfg.phaseCrossline.searchMarginPx = 18;
cfg.phaseCrossline.amplitudePercentile = 65;
cfg.phaseCrossline.minimumLinePoints = 8;
cfg.phaseCrossline.maximumCorrectionPx = 20;
cfg.phaseCrossline.minimumQuality = 0.35;

cfg.compensation.mode = 'adaptive_macro'; % 趋势+快速大偏差补偿；trend/band_protected 仅低通
cfg.compensation.cutoffHz = 1;
cfg.compensation.windowSeconds = 0.5;
cfg.compensation.robustWindowFrames = 5;
cfg.compensation.fastMotionThresholdPx = 2.0;
cfg.compensation.targetBandHz = [];
cfg.compensation.bandGuardFraction = 0.80;
cfg.compensation.trackingAxis = 'xy';
cfg.compensation.outlierWindowSeconds = 0.15;
cfg.compensation.geometryDisplacement = [];

cfg.crop.mode = 'integer'; % integer / canonical_warp（后者只用于插值偏差对照）
cfg.crop.interpolation = 'bilinear';

cfg.io.captureFps = [];
cfg.io.fpsOverride = [];
cfg.io.startSeconds = 0;
cfg.io.durationSeconds = Inf;
cfg.io.previewFps = 30;
cfg.io.writePreview = false;
cfg.io.diagnosticsDirectory = '';
end
