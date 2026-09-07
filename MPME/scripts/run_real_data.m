%RUN_REAL_DATA 动态 ROI 入口：使用一个前端跟踪器处理大运动真实视频。
% 静态/论文基线请运行同目录的 run_real_data_paper.m；两者共用本文件的 M-PME 后端。
% 只需修改“用户配置”中的一个 videoPath。ROI 为空时会像参考 main.m 一样，
% 在首帧上拖动矩形并双击确认；程序不会再用硬编码坐标覆盖人工选择。
% 本文件采用 UTF-8 中文注释，请勿用 ANSI/GBK 编码另存。

close all; clearvars; clc; warning off;
totalTimer = tic;
processingTime = struct();

%% 1. 工程路径与用户配置
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot,'src'));

config.videoPath = 'C:\0819\4-25mvpp-motion.avi';
config.outputDirectory = 'D:\LunFu\MPME\outputs\0819\4-25mvpp-motion';
config.outputName = '4-25mvpp-motion';            % 输出目录名仅用于记录
config.motionModel = 'translation';        % 'translation' 或 'rotation'
config.roi = [];                         % 留空可交互框选；也可回填 [x y width height]
config.maxFrames = 1800;                % 最多读取帧数；Inf 表示全部
config.fpsOverride = 100;                  % 留空使用视频帧率
config.referenceMode = 'fixed';       % 兼容旧配置；平移: fixed   旋转: adjacent
config.primaryAxis = 'x';                % 与激光真值对比的视觉分量：'x'、'y' 或 'angle'
config.frequencyRangeHz = [0.05 50];      % 频谱主峰搜索范围
config.writeTrackingVideo = false; % 调试跟踪框时改为 true；正式测量默认不编码视频
config.writeTrackingDiagnostics = false; % 逐帧诊断图/CSV按需开启，默认不拖慢正式测量
config.output.clearPreviousResults = true; % 同一目录每次只保留本次运行生成的文件

% 动态 ROI：第一遍粗跟踪得到宏观轨迹，第二遍按整数轨迹裁剪，
% 微振动残差仍留给 M-PME。固定机位旋转由 followHubTranslation 自动决定是否启用。
config.dynamicRoi.enabled = true;
% VP-DROI 模式：integer_macro=跟随完整整数宏观轨迹并保留亚像素残差（正式默认）；
% trend=只跟随低频大运动；full=跟随全部跟踪中心（验证用）；
% fixed=固定 ROI 基线，不启用动态跟踪。
config.dynamicRoi.mode = 'adaptive_macro';
config.dynamicRoi.preserveVibration = true;
config.dynamicRoi.writePreviewVideo = false; % 预览编码会额外完整写一遍视频，正式测量默认关闭
config.dynamicRoi.maximumPoints = 120;
config.dynamicRoi.minimumPoints = 5;
config.dynamicRoi.redetectPointCount = 15;
config.dynamicRoi.redetectInterval = 30;
config.dynamicRoi.minimumQuality = 0.005;
config.dynamicRoi.maximumBidirectionalError = 2;
config.dynamicRoi.pyramidLevels = 3;
config.dynamicRoi.outlierFloorPixels = 1.5;
config.dynamicRoi.maximumStepPixels = 80;
config.dynamicRoi.fallbackVelocityDecay = 0.75;
config.dynamicRoi.previewFps = 30;
config.dynamicRoi.largeMotionCutoffHz = 1; % ROI 只跟随低于该频率的大运动
config.dynamicRoi.macroTrendCutoffHz = []; % 留空时由时间窗/largeMotionCutoffHz决定
config.dynamicRoi.macroTrendWindowSeconds = 0.5; % 物理时间窗；默认对应约 1 Hz 截止
config.dynamicRoi.trajectoryOutlierWindowSeconds = 0.15;
config.dynamicRoi.trackingAxis = 'auto';  % 平移按 primaryAxis；旋转使用 'xy'
config.dynamicRoi.translationResidualLevels = 2;
config.dynamicRoi.translationSampleStep = 4;
% 真实视频默认恢复论文式四方向约束；仅在明确需要加速时改为 true。
config.dynamicRoi.useSingleDirectionForSpeed = false;
config.dynamicRoi.translationDirectionsX = 0;  % 仅在上项为 true 时使用
config.dynamicRoi.translationDirectionsY = 90; % 仅在上项为 true 时使用
config.dynamicRoi.templateVerificationEnabled = true; % 固定首帧边缘模板防止 KLT 换目标
config.dynamicRoi.templateVerificationInterval = 5;
config.dynamicRoi.templateSearchMarginPixels = 24;
config.dynamicRoi.templateMaximumCorrectionPixels = 12;
config.dynamicRoi.templateMinimumScore = 0.20;
config.dynamicRoi.targetBandHz = [2 30]; % band_protected 模式用于保护的微振动频带
config.dynamicRoi.phaseCrosslineEnabled = false; % 贴十字标志时开启；每帧用相位零交叉精定位

% 粗跟踪器选择：只替换动态 ROI 跟踪层，后端 M-PME/PNL/频谱流程不变。
% 可选：'rmptf'、'rmptf_crossline'、'klt'、'fdsst'、'fdsst_improved'、'eco_improved'。
% fDSST/ECO 能输出随尺度变化的 ROI；ECO 运行较慢，建议先用短视频验证。
config.tracker.type = 'rmptf'; % 单遍 RMPTF hybrid；需 fDSST 时显式改为 rmptf_fdsst
config.tracker.fdsstOriginalRoot = ...
    'C:\Users\SPRING\Desktop\师兄\第四章实验\程序\DSST';
config.tracker.fdsstImprovedRoot = ...
    fullfile(fileparts(projectRoot),'AP-CV','third_party','fdsst_sunjiajian');
config.tracker.ecoRoot = ...
    'D:\方法库备份\ECO备份\ECO-master';
config.tracker.ecoWrapperRoot = ...
    'C:\Users\SPRING\Desktop\师兄\第四章实验\程序\Tracking';
config.tracker.fdsstOptions = struct();
config.tracker.ecoOptions = struct('visualization',0,'use_gpu',false);

% 平移参考策略：auto 先用固定首帧；若出现接近一个 Gabor 波长的折返，自动
% 改用相邻帧积分。相邻结果可能缓慢漂移，但微振动零相位带通不受该漂移影响。
config.translation.referenceMode = 'auto'; % 'auto'、'fixed' 或 'adjacent'
config.translation.phaseJumpFraction = 0.45;
config.translation.useProfileValidator = true; % 独立一维边缘相关，仅作校验/回退依据
config.translation.profileMaximumStepPixels = 5;

% M-PME 配置；lambda 和层数应按 ROI 尺寸、最大帧间运动调整。
config.mpme.levels = 4;
config.mpme.lambda = 30;
config.mpme.directions = [0 45 90 135]; % 论文式四方向 Gabor 约束
config.mpme.bandwidth = 1;
config.mpme.psi = 0;
config.mpme.supportSigma = 2;
config.mpme.confidenceThreshold = 25;
config.mpme.confidencePercentile = 55;
config.mpme.useDirectionMask = false;
config.mpme.sampleStep = 2;
config.mpme.iterationsPerLevel = 1;
config.mpme.usePhaseNonlinearityWeight = true;
config.mpme.phaseNonlinearityWindow = 7;
config.mpme.phaseNonlinearityScale = 0.35;
config.mpme.phaseNonlinearityPercentile = 88;
config.performance.cacheFixedReference = true; % 固定首帧时缓存金字塔/Gabor，结果不变

% 旋转视频配置；坐标均为 ROI 内 0-based。留空时按顺序交互点击。
config.rotation.hubCenter = [];
config.rotation.measurementPoints = [];
config.rotation.measurementPointCount = 3;
config.rotation.useAbsolutePhaseAnchor = true;
config.rotation.symmetryOrder = 1;        % 外观呈 N 重对称时填 N，例如五叶片填 5
config.rotation.minimumAnchorQuality = 1.02;
config.rotation.maximumAnchorCorrectionDegrees = 3; % 仅允许小漂移修正，拒绝叶片周期歧义
config.rotation.followHubTranslation = false; % 固定机位风扇应为 false，避免 KLT 追逐叶片
config.rotation.method = 'mpme'; % 高速重复叶片推荐 angular-harmonic；低速非周期目标用 'mpme'
config.rotation.bladeCount = 5;          % 必须与真实叶片数一致
config.rotation.harmonicAngularSamples = 720;
config.rotation.harmonicRadialSamples = 96;
config.rotation.autoCorrectHubTowardRoiCenter = true; % 整机 ROI 应尽量以轮毂为中心
config.rotation.maximumHubOffsetFraction = 0.12;
config.rotation.autoExpandInnerMeasurementPoints = true; % 仅改善轨迹可视化，不改变测角
config.rotation.useHybridCoarsePhase = true; % 粗转角对齐后由 M-PME 测残差
config.rotation.coarseMethod = 'flow';   % 'flow' 推荐；'klt' 为可选回退
config.rotation.residualLevels = 2;       % 粗转角对齐后只需处理小残差
config.rotation.sampleStep = 4;
config.rotation.directions = [0 45 90 135]; % 论文式四方向 Gabor 约束
config.rotation.analysisInnerRadiusPixels = 8;
config.rotation.analysisOuterScale = 1.15; % 相对最远测点半径，自动形成转子掩膜
config.rotation.kltMaximumPoints = 200;
config.rotation.kltRedetectInterval = 5;
config.rotation.kltMinimumMovingPoints = 3;
config.rotation.flowMotionMaskPercentile = 65; % 自动排除静态背景

% 可选 LDV/三角激光真值。把 true 改为 false 即可关闭整组对比和相关输出。
config.reference.enabled = false;
config.reference.filePath = 'E:\sanjiao\0726\man-qiao.csv';
config.reference.fileType = 'csv';
% 下列四项与三角光程序截图中的变量一一对应，换数据时通常只改这里。
config.reference.laserFs = 100;           % laserFs：采样率（Hz）
config.reference.laserGraphNumber = 1;    % LaserGraphNumber：曲线/图号
config.reference.laserColumnNumber = 3;   % LaserColumnNumber：CSV 中的位移列
config.reference.laserInvalidThreshold = -900; % LaserInvalidThreshold：无效值阈值
config.reference.csvTimeColumn = [];      % 留空时按样本序号 / laserFs 生成时间
config.reference.timeVariable = 'time';
config.reference.displacementVariable = 'displacement';
config.reference.pixelsPerUnit = 1;       % 真值单位转换到 px；角度对比时填 deg/unit
config.reference.autoAlign = true;
config.reference.manualLagSeconds = 0;    % autoAlign=false 时使用；正值表示真值向后移动
config.reference.alignmentBandHz = [0.5 30];
config.reference.maximumAlignmentLagSeconds = 5;
config.acceleration.lowpassHz = 30;        % 位移二次微分后的低通截止频率

% 大运动/微振动分离：零相位滤波仅生成派生结果，原始总位移始终保存在 CSV/MAT。
config.microVibration.enabled = true;
config.microVibration.bandHz = [5 30];    % 按实验预期频率修改，例如 6.6 Hz 包含在内
config.microVibration.frequencySearchBandHz = []; % 已知频率时建议填窄带，如 [5 9]
config.microVibration.filterOrder = 3;
config.microVibration.minimumConsensusCorrelation = 0.35;
config.microVibration.maximumFrequencyDifferenceHz = 0.75;

if isempty(config.videoPath)
    fprintf(['尚未填写 config.videoPath。请在 run_real_data.m 顶部只配置一个视频，\n' ...
        '然后重新运行；ROI、轮毂和测点都可在首帧上交互选择。\n']);
    return;
end
if ~isfile(config.videoPath), error('找不到视频：%s',config.videoPath); end

%% 2. 首帧 ROI 框选与视频读取
roiSelectionTimer = tic;
if isfield(config,'outputDirectory') && ~isempty(config.outputDirectory)
    outputDirectory = config.outputDirectory;
else
    outputDirectory = fullfile(projectRoot,'outputs','real_data',config.outputName);
end
prepare_output_directory(outputDirectory,projectRoot, ...
    config.output.clearPreviousResults);
[roi,firstFrame,firstCrop] = select_video_roi(config.videoPath,config.roi, ...
    '请框选本次真实视频的处理 ROI');
processingTime.roiSelectionSeconds = toc(roiSelectionTimer);
save_roi_preview(firstFrame,roi,firstCrop, ...
    fullfile(outputDirectory,'01_roi_selection.png'),'真实视频 ROI');
save_single_frame_figure(firstCrop,fullfile(outputDirectory,'02_roi_input.png'), ...
    'ROI 首帧输入');
loadingTimer = tic;
dynamicRoiActive = config.dynamicRoi.enabled && ...
    ~strcmpi(config.dynamicRoi.mode,'fixed');
if strcmpi(config.motionModel,'rotation') && ~config.rotation.followHubTranslation
    dynamicRoiActive = false;
end
config.dynamicRoi.activeForThisRun = dynamicRoiActive;
if dynamicRoiActive
    if config.dynamicRoi.writePreviewVideo
        dynamicRoiVideoPath = fullfile(outputDirectory,'02_dynamic_roi_tracking.mp4');
    else
        dynamicRoiVideoPath = '';
    end
    dynamicOptions = config.dynamicRoi;
    if strcmpi(dynamicOptions.trackingAxis,'auto')
        if strcmpi(config.motionModel,'rotation')
            dynamicOptions.trackingAxis = 'xy';
        else
            dynamicOptions.trackingAxis = config.primaryAxis;
        end
    end
    % 这里始终只调用一次 VP-DROI 前端。tracker.type 只决定一个后端，
    % 不会先跑 KLT 再跑 fDSST/ECO；后面的 M-PME 是测量器，不是第二个 ROI 跟踪器。
    dynamicOptions.trackerType = config.tracker.type;
    dynamicOptions.fdsstOriginalRoot = config.tracker.fdsstOriginalRoot;
    dynamicOptions.fdsstImprovedRoot = config.tracker.fdsstImprovedRoot;
    dynamicOptions.ecoRoot = config.tracker.ecoRoot;
    dynamicOptions.ecoWrapperRoot = config.tracker.ecoWrapperRoot;
    dynamicOptions.fdsstOptions = config.tracker.fdsstOptions;
    dynamicOptions.ecoOptions = config.tracker.ecoOptions;
    dynamicOptions.captureFps = config.fpsOverride;
    if isfield(config,'writeTrackingDiagnostics') && config.writeTrackingDiagnostics
        dynamicOptions.diagnosticsDirectory = fullfile(outputDirectory,'rmptf_diagnostics');
    else
        dynamicOptions.diagnosticsDirectory = '';
    end
    [frames,videoFps,roiTrajectory,roiTracking] = ...
        load_video_dynamic_roi(config.videoPath,config.maxFrames,roi, ...
        dynamicOptions,dynamicRoiVideoPath);
else
    [frames,videoFps] = load_video_gray(config.videoPath,config.maxFrames,roi);
    roiTrajectory = repmat(double(roi),size(frames,3),1);
    roiTracking = struct('coarseDisplacement',zeros(size(frames,3),2), ...
        'trackerType','fixed','frontTrackerType','fixed', ...
        'frontTrackerCallCount',0,'frontTrackerOnly',true, ...
        'dynamicRoiMode','fixed', ...
        'validPointCount',nan(size(frames,3),1),'quality',nan(size(frames,3),1), ...
        'fallbackUsed',false(size(frames,3),1),'hitBoundary',false(size(frames,3),1), ...
        'rawCoarseDisplacement',zeros(size(frames,3),2), ...
        'largeMotionContinuous',zeros(size(frames,3),2), ...
        'kltMicroCandidate',zeros(size(frames,3),2), ...
        'templateScore',nan(size(frames,3),1), ...
        'templateCorrectionUsed',false(size(frames,3),1), ...
        'redetectionUsed',false(size(frames,3),1), ...
        'rawRoiTrajectory',roiTrajectory,'bbox_xywh',roiTrajectory, ...
        'center_xy',roiTrajectory(:,1:2)+0.5*roiTrajectory(:,3:4), ...
        'scale',ones(size(frames,3),2),'confidence',nan(size(frames,3),1), ...
        'valid',true(size(frames,3),1),'lost',false(size(frames,3),1), ...
        'redetect',false(size(frames,3),1), ...
        'fallbackFrameCount',0,'templateCorrectionFrameCount',0, ...
        'boundaryFrameCount',0,'previewWritingSeconds',0, ...
        'expectedCoarseDisplacement',zeros(size(frames,3),2), ...
        'macroTrendDiagnostics',struct('mode','fixed','cutoffHz',0), ...
        'macro',struct('xy',zeros(size(frames,3),2), ...
            'microCandidate',zeros(size(frames,3),2)), ...
        'crop',struct('origin_xy',roiTrajectory(:,1:2), ...
            'bbox_xywh',roiTrajectory,'valid',true(size(frames,3),1)));
end
loadingElapsed = toc(loadingTimer);
processingTime.dynamicRoiPreviewVideoSeconds = roiTracking.previewWritingSeconds;
processingTime.videoLoadingAndRoiTrackingSeconds = max(0, ...
    loadingElapsed-roiTracking.previewWritingSeconds);
if isempty(config.fpsOverride), fps = videoFps; else, fps = config.fpsOverride; end
frameCount = size(frames,3);
time = (0:frameCount-1).'/fps;
if dynamicRoiActive
    export_vp_droi_diagnostics(outputDirectory,time,roiTracking,roiTrajectory, ...
        roi,fps,struct('trackerType',roiTracking.trackerType, ...
        'mode',roiTracking.dynamicRoiMode, ...
        'macroTrendCutoffHz',roiTracking.macroTrendDiagnostics.cutoffHz, ...
        'trackingAxis',config.dynamicRoi.trackingAxis, ...
        'preserveVibration',config.dynamicRoi.preserveVibration));
end
frequencyRange = [max(0,config.frequencyRangeHz(1)) ...
    min(fps/2,config.frequencyRangeHz(2))];

params = config.mpme;
params.model = 'affine';
params.cacheFixedReference = config.performance.cacheFixedReference;
if dynamicRoiActive && strcmpi(config.motionModel,'translation')
    % 大运动已由 VP-DROI 趋势裁剪去除，M-PME 主要处理小残差；这里仅降低
    % 层数/采样密度，方向默认仍保留论文的 0/45/90/135 度四方向约束。
    params.levels = min(params.levels,config.dynamicRoi.translationResidualLevels);
    params.sampleStep = max(params.sampleStep,config.dynamicRoi.translationSampleStep);
    if config.dynamicRoi.useSingleDirectionForSpeed
        % 可选加速开关：这不是论文 baseline，且可能降低移动场景的鲁棒性。
        if strcmpi(config.primaryAxis,'x')
            params.directions = config.dynamicRoi.translationDirectionsX;
        elseif strcmpi(config.primaryAxis,'y')
            params.directions = config.dynamicRoi.translationDirectionsY;
        end
    else
        params.directions = config.mpme.directions;
    end
end
diagnosticTimer = tic;
save_pyramid_levels_single(frames(:,:,1),params.levels,outputDirectory,'03');
if frameCount>=2
    save_gabor_outputs_single(frames(:,:,1),frames(:,:,2),params,outputDirectory,'04');
end
processingTime.diagnosticFigureSeconds = toc(diagnosticTimer);

%% 3. 同一处理流程，仅由运动模型配置决定平移或旋转
hubCenter = [];
measurementPoints = [];
rawStepAngles = nan(frameCount,1);
integratedStepAngles = nan(frameCount,1);
absoluteAngles = nan(frameCount,1);
anchorAngles = nan(frameCount,1);
anchorQuality = nan(frameCount,1);
pointTracks = [];
pointTracksLocal = [];
rotationCoarseSteps = nan(frameCount,1);
rotationCoarseValidCount = nan(frameCount,1);
rotationCoarseMovingCount = nan(frameCount,1);
rotationCoarseFallback = false(frameCount,1);
profileTotalDisplacement = nan(frameCount,1);
profileTrackingQuality = nan(frameCount,1);
selectedTranslationReferenceMode = 'not-applicable';
phaseResidualMaximumJump = NaN;
medianRotationRpm = NaN;
meanRotationRpm = NaN;
speedRpm = nan(frameCount,1);
speedRpmRobust = nan(frameCount,1);
maximumUnambiguousRpm = NaN;
rotationAliasingRisk = false;
measurementPointRadiusAdequate = true;
measurementPointsAutoAdjusted = false;
rotationFrequencyHz = NaN;
bladePassFrequencyHz = NaN;
xDisplacement = nan(frameCount,1);
yDisplacement = nan(frameCount,1);
coarseDisplacement = roiTracking.coarseDisplacement;
motionTimer = tic;

if strcmpi(config.motionModel,'rotation')
    hubCenter = select_points_on_frame(firstCrop,1,'请选择风扇/叶片轮毂中心', ...
        config.rotation.hubCenter);
    roiImageCenter = [(size(frames,2)-1)/2 (size(frames,1)-1)/2];
    maximumHubOffset = config.rotation.maximumHubOffsetFraction* ...
        min([size(frames,1) size(frames,2)]);
    if config.rotation.autoCorrectHubTowardRoiCenter && ...
            norm(hubCenter-roiImageCenter)>maximumHubOffset
        fprintf(['轮毂中心 %s 距完整转子 ROI 中心 %s 过远，已自动改为 ROI 中心。' ...
            '若 ROI 本身并非以轮毂为中心，请关闭 autoCorrectHubTowardRoiCenter 并重新点选。'], ...
            mat2str(hubCenter,4),mat2str(roiImageCenter,4));
        hubCenter = roiImageCenter;
    end
    measurementPoints = select_points_on_frame(firstCrop, ...
        config.rotation.measurementPointCount,'请选择叶片测量点', ...
        config.rotation.measurementPoints);
    inscribedRotorRadius = min([hubCenter(1),hubCenter(2), ...
        size(frames,2)-1-hubCenter(1),size(frames,1)-1-hubCenter(2)]);
    harmonicOuterRadius = 0.90*inscribedRotorRadius;
    pointVectors = measurementPoints-hubCenter;
    pointRadii = hypot(pointVectors(:,1),pointVectors(:,2));
    measurementPointRadiusAdequate = max(pointRadii)>=0.50*harmonicOuterRadius;
    if ~measurementPointRadiusAdequate && ...
            config.rotation.autoExpandInnerMeasurementPoints
        targetRadius = 0.75*harmonicOuterRadius;
        for pointIndex = 1:size(measurementPoints,1)
            if pointRadii(pointIndex)>eps
                pointVectors(pointIndex,:) = pointVectors(pointIndex,:)/ ...
                    pointRadii(pointIndex)*targetRadius;
            else
                pointAngle = 2*pi*(pointIndex-1)/size(measurementPoints,1);
                pointVectors(pointIndex,:) = targetRadius*[cos(pointAngle) sin(pointAngle)];
            end
        end
        measurementPoints = hubCenter+pointVectors;
        pointRadii(:) = targetRadius;
        measurementPointsAutoAdjusted = true;
        fprintf(['\n测点原先都靠近轮毂，已沿各自方向移到转子半径的 75%%，' ...
            '仅用于让轨迹图清晰；转角/转速不依赖这些虚拟测点。\n']);
    elseif ~measurementPointRadiusAdequate
        fprintf(['\n测点离轮毂过近，轨迹图位移会很小。请把测点选在叶片中外段；' ...
            '本次转角/转速仍由完整环形区域估计。\n']);
    end
    save_single_frame_figure(firstCrop,fullfile(outputDirectory,'05_measurement_points.png'), ...
        '轮毂中心与测量点',measurementPoints,hubCenter);

    params.model = 'rotation';
    params.enforceRigid = true;
    params.rigidCenter = hubCenter;
    params.levels = min(params.levels,config.rotation.residualLevels);
    params.sampleStep = max(params.sampleStep,config.rotation.sampleStep);
    params.directions = config.rotation.directions;
    [maskX,maskY] = meshgrid(0:size(frames,2)-1,0:size(frames,1)-1);
    outerRadius = max(pointRadii)*config.rotation.analysisOuterScale;
    radiusMap = hypot(maskX-hubCenter(1),maskY-hubCenter(2));
    params.mask = radiusMap>=config.rotation.analysisInnerRadiusPixels & ...
        radiusMap<=outerRadius;
    if strcmpi(config.rotation.method,'angular-harmonic')
        harmonicOptions = struct('angularSamples', ...
            config.rotation.harmonicAngularSamples,'radialSamples', ...
            config.rotation.harmonicRadialSamples,'innerRadiusPixels', ...
            config.rotation.analysisInnerRadiusPixels, ...
            'outerRadiusPixels',harmonicOuterRadius);
        [absoluteAngles,anchorQuality,harmonicDiagnostics] = ...
            track_rotation_angular_harmonic(frames,hubCenter, ...
            config.rotation.bladeCount,harmonicOptions);
        diagnostics = harmonicDiagnostics;
        rawStepAngles = [0;diff(absoluteAngles)];
        integratedStepAngles = rawStepAngles;
        anchorAngles = absoluteAngles;
        rotationCoarseSteps = rawStepAngles;
        rotationCoarseValidCount = anchorQuality;
        rotationCoarseMovingCount = anchorQuality;
        rotationCoarseFallback = harmonicDiagnostics.rejectedFrames;
        maximumUnambiguousRpm = 30*fps/config.rotation.bladeCount;
        rotationAliasingRisk = prctile(abs(rawStepAngles(2:end)),99)>= ...
            0.90*harmonicDiagnostics.maximumUnambiguousStepDegrees;
        transforms = repmat(eye(3),1,1,frameCount);
        centreColumn = hubCenter(:);
        for frameIndex = 2:frameCount
            angleRadians = deg2rad(absoluteAngles(frameIndex));
            rotationMatrix = [cos(angleRadians) -sin(angleRadians); ...
                sin(angleRadians) cos(angleRadians)];
            translationColumn = centreColumn-rotationMatrix*centreColumn;
            transforms(:,:,frameIndex) = ...
                [rotationMatrix translationColumn;0 0 1];
        end
    elseif config.rotation.useHybridCoarsePhase
        coarseRotationOptions = struct('coarseMethod',config.rotation.coarseMethod, ...
            'maximumPoints',config.rotation.kltMaximumPoints, ...
            'minimumTrackPoints',5,'minimumMovingPoints', ...
            config.rotation.kltMinimumMovingPoints,'redetectPointCount',10, ...
            'redetectInterval',config.rotation.kltRedetectInterval, ...
            'maximumBidirectionalError',3,'pyramidLevels',4, ...
            'minimumMotionPixels',0.1,'maximumRadialDriftPixels',6, ...
            'innerRadiusPixels',config.rotation.analysisInnerRadiusPixels, ...
            'outerRadiusPixels',outerRadius, ...
            'motionMaskPercentile',config.rotation.flowMotionMaskPercentile);
        [adjacentTransforms,diagnostics,rotationCoarseSteps,coarseRotationTracking] = ...
            track_sequence_rotation_hybrid(frames,params,coarseRotationOptions);
        rotationCoarseValidCount = coarseRotationTracking.validPointCount;
        rotationCoarseMovingCount = coarseRotationTracking.movingPointCount;
        rotationCoarseFallback = coarseRotationTracking.fallbackUsed;
    else
        [adjacentTransforms,diagnostics] = track_sequence_affine(frames,params,'adjacent');
    end
    if ~strcmpi(config.rotation.method,'angular-harmonic')
        [integratedTransforms,rawStepAngles,integratedStepAngles] = ...
            stabilize_rotation_sequence(adjacentTransforms, ...
            [size(frames,1) size(frames,2)],5,hubCenter);
        if config.rotation.useAbsolutePhaseAnchor
            anchorOptions = struct('angularSamples',720,'radialSamples',72, ...
                'radiusFraction',[0.10 0.48], ...
                'minimumQuality',config.rotation.minimumAnchorQuality, ...
                'maximumCorrectionDegrees',config.rotation.maximumAnchorCorrectionDegrees, ...
                'symmetryOrder',config.rotation.symmetryOrder);
            [transforms,absoluteAngles,anchorAngles,anchorQuality] = ...
                anchor_rotation_sequence(frames,integratedTransforms,hubCenter,anchorOptions);
        else
            transforms = integratedTransforms;
            absoluteAngles = cumsum(integratedStepAngles);
        end
    end

    processingTime.motionEstimationSeconds = toc(motionTimer);
    pointCount = size(measurementPoints,1);
    pointTracksLocal = zeros(pointCount,2,frameCount);
    for frameIndex = 1:frameCount
        pointTracksLocal(:,:,frameIndex) = transform_points_h( ...
            transforms(:,:,frameIndex),measurementPoints);
    end
    pointTracks = pointTracksLocal;
    pointTracks(:,1,:) = pointTracks(:,1,:)+reshape(coarseDisplacement(:,1),1,1,[]);
    pointTracks(:,2,:) = pointTracks(:,2,:)+reshape(coarseDisplacement(:,2),1,1,[]);
    for pointIndex = 1:pointCount
        xSignal = squeeze(pointTracks(pointIndex,1,:))-measurementPoints(pointIndex,1);
        ySignal = squeeze(pointTracks(pointIndex,2,:))-measurementPoints(pointIndex,2);
        save_motion_spectrum_figure(time,[xSignal ySignal],{'x','y'},fps,frequencyRange, ...
            fullfile(outputDirectory,sprintf('06_point_P%d_waveform_spectrum.png',pointIndex)), ...
            '位移 (px)',sprintf('测点 P%d 位移与频谱',pointIndex),true);
    end
    xDisplacement = squeeze(pointTracks(1,1,:))-measurementPoints(1,1);
    yDisplacement = squeeze(pointTracks(1,2,:))-measurementPoints(1,2);
    save_motion_spectrum_figure(time,absoluteAngles,{'绝对转角'},fps,frequencyRange, ...
        fullfile(outputDirectory,'07_angle_waveform_spectrum.png'),'角度 (deg)', ...
        '首帧相位锚定后的转角');

    speedRpm = [nan; diff(absoluteAngles)*fps/360*60];
    speedRpmRobust = smoothdata(fillmissing(speedRpm,'nearest'), ...
        'movmedian',max(5,2*floor(0.25*fps/2)+1));
    medianRotationRpm = median(speedRpm,'omitnan');
    meanRotationRpm = mean(speedRpm,'omitnan');
    rotationFrequencyHz = abs(medianRotationRpm)/60;
    bladePassFrequencyHz = rotationFrequencyHz*config.rotation.bladeCount;
    speedFigure = figure('Visible','off','Color','w','Position',[50 50 620 390]);
    plot(time,speedRpm,'Color',[0.72 0.72 0.72],'LineWidth',0.65); hold on;
    plot(time,speedRpmRobust,'Color',[0 0.45 0.70],'LineWidth',1.15); grid on; box on;
    xlabel('时间 (s)'); ylabel('转速 (r/min)'); title('瞬时转速','FontWeight','normal');
    legend('原始谐波相位差分','0.25 s 鲁棒中值','Location','best','Box','off');
    set(gca,'FontName','Microsoft YaHei','FontSize',9,'TickDir','out');
    exportgraphics(speedFigure,fullfile(outputDirectory,'08_rotation_speed.png'),'Resolution',240);
    close(speedFigure);
else
    params.model = 'translation';
    params.primaryAxis = config.primaryAxis;
    requestedReferenceMode = lower(config.translation.referenceMode);
    if strcmp(requestedReferenceMode,'auto')
        selectedTranslationReferenceMode = 'fixed';
    else
        selectedTranslationReferenceMode = requestedReferenceMode;
    end
    [transforms,diagnostics] = track_sequence_affine( ...
        frames,params,selectedTranslationReferenceMode);
    if strcmpi(config.primaryAxis,'y')
        phaseResidual = squeeze(transforms(2,3,:));
    else
        phaseResidual = squeeze(transforms(1,3,:));
    end
    phaseResidualMaximumJump = max(abs(diff(phaseResidual)));
    phaseJumpLimit = config.translation.phaseJumpFraction*params.lambda;
    if strcmp(requestedReferenceMode,'auto') && ...
            phaseResidualMaximumJump>phaseJumpLimit
        fprintf(['固定首帧残差出现 %.3f px 跳变（阈值 %.3f px），' ...
            '自动改用相邻帧参考以避免整周期相位折返。\n'], ...
            phaseResidualMaximumJump,phaseJumpLimit);
        [transforms,diagnostics] = track_sequence_affine(frames,params,'adjacent');
        selectedTranslationReferenceMode = 'adjacent-auto-fallback';
        if strcmpi(config.primaryAxis,'y')
            phaseResidual = squeeze(transforms(2,3,:));
        else
            phaseResidual = squeeze(transforms(1,3,:));
        end
        phaseResidualMaximumJump = max(abs(diff(phaseResidual)));
    end
    xDisplacement = squeeze(transforms(1,3,:));
    yDisplacement = squeeze(transforms(2,3,:));
    if config.translation.useProfileValidator
        profileOptions = struct('referenceMode','adjacent', ...
            'maximumShiftPixels',config.translation.profileMaximumStepPixels);
        [profileResidual,profileTrackingQuality] = track_translation_profile( ...
            frames,config.primaryAxis,profileOptions);
        if strcmpi(config.primaryAxis,'y')
            profileTotalDisplacement = coarseDisplacement(:,2)+profileResidual;
        else
            profileTotalDisplacement = coarseDisplacement(:,1)+profileResidual;
        end
    end
    measurementPoints = [(size(frames,2)-1)/2 (size(frames,1)-1)/2];
    pointTracksLocal = zeros(1,2,frameCount);
    for frameIndex = 1:frameCount
        pointTracksLocal(:,:,frameIndex) = transform_points_h( ...
            transforms(:,:,frameIndex),measurementPoints);
    end
    pointTracks = pointTracksLocal;
    pointTracks(:,1,:) = pointTracks(:,1,:)+reshape(coarseDisplacement(:,1),1,1,[]);
    pointTracks(:,2,:) = pointTracks(:,2,:)+reshape(coarseDisplacement(:,2),1,1,[]);
    xDisplacement = coarseDisplacement(:,1)+xDisplacement;
    yDisplacement = coarseDisplacement(:,2)+yDisplacement;
    processingTime.motionEstimationSeconds = toc(motionTimer);
    save_motion_spectrum_figure(time,xDisplacement,{'M-PME x'},fps,frequencyRange, ...
        fullfile(outputDirectory,'06_x_waveform_spectrum.png'),'x 位移 (px)','水平位移',true);
    save_motion_spectrum_figure(time,yDisplacement,{'M-PME y'},fps,frequencyRange, ...
        fullfile(outputDirectory,'07_y_waveform_spectrum.png'),'y 位移 (px)','竖直位移',true);
end
if dynamicRoiActive
    save_motion_spectrum_figure(time,coarseDisplacement,{'ROI x','ROI y'}, ...
        fps,frequencyRange,fullfile(outputDirectory,'05_dynamic_roi_motion.png'), ...
        '粗位移 (px)','动态 ROI 粗运动');
end
processingTime.motionFigureSeconds = max(0,toc(motionTimer)- ...
    processingTime.motionEstimationSeconds);
microTimer = tic;

largeMotionSignal = nan(frameCount,1);
microVibrationSignal = nan(frameCount,1);
kltMicroSignal = nan(frameCount,1);
profileMicroSignal = nan(frameCount,1);
microDominantFrequency = NaN;
vibrationDominantFrequency = NaN;
totalDominantFrequency = NaN;
kltDominantFrequency = NaN;
profileDominantFrequency = NaN;
microKltCorrelation = NaN;
microReliable = false;
microFrequencySearchBand = config.microVibration.bandHz;
microSearchBandIsUserConstrained = false;
if ~isempty(config.microVibration.frequencySearchBandHz)
    microFrequencySearchBand = config.microVibration.frequencySearchBandHz;
    microSearchBandIsUserConstrained = true;
end
if config.microVibration.enabled && strcmpi(config.motionModel,'translation')
    if strcmpi(config.primaryAxis,'y')
        primarySignalForSeparation = yDisplacement;
        kltCandidate = roiTracking.kltMicroCandidate(:,2);
    else
        primarySignalForSeparation = xDisplacement;
        kltCandidate = roiTracking.kltMicroCandidate(:,1);
    end
    [largeMotionSignal,microVibrationSignal] = separate_motion_bands( ...
        primarySignalForSeparation,fps,config.microVibration);
    [~,kltMicroSignal] = separate_motion_bands( ...
        kltCandidate,fps,config.microVibration);
    if config.translation.useProfileValidator
        [~,profileMicroSignal] = separate_motion_bands( ...
            profileTotalDisplacement,fps,config.microVibration);
    end
    [microDominantFrequency,~,~] = estimate_dominant_frequency( ...
        microVibrationSignal,fps,microFrequencySearchBand);
    vibrationDominantFrequency = microDominantFrequency;
    [kltDominantFrequency,~,~] = estimate_dominant_frequency( ...
        kltMicroSignal,fps,microFrequencySearchBand);
    if config.translation.useProfileValidator
        [profileDominantFrequency,~,~] = estimate_dominant_frequency( ...
            profileMicroSignal,fps,microFrequencySearchBand);
    end
    validCorrelation = isfinite(microVibrationSignal) & isfinite(kltMicroSignal);
    if nnz(validCorrelation)>=20
        correlationMatrix = corrcoef(microVibrationSignal(validCorrelation), ...
            kltMicroSignal(validCorrelation));
        microKltCorrelation = correlationMatrix(1,2);
    end
    frequencyAgreement = abs(microDominantFrequency-kltDominantFrequency)<= ...
        config.microVibration.maximumFrequencyDifferenceHz;
    if config.translation.useProfileValidator
        frequencyAgreement = frequencyAgreement || ...
            abs(microDominantFrequency-profileDominantFrequency)<= ...
            config.microVibration.maximumFrequencyDifferenceHz;
    end
    if dynamicRoiActive
        % 动态入口要求 M-PME 与前端轨迹在频率和波形上形成共识。
        microReliable = frequencyAgreement && ...
            abs(microKltCorrelation)>=config.microVibration.minimumConsensusCorrelation;
    else
        % 固定 ROI 没有前端轨迹可供共识校验，可靠度只表示 M-PME 成功得到主频。
        microReliable = isfinite(microDominantFrequency);
    end
    microSignals = microVibrationSignal;
    microNames = {'M-PME 最终微振动'};
    if dynamicRoiActive
        microSignals(:,end+1) = kltMicroSignal;
        microNames{end+1} = sprintf('%s 原始轨迹带通',roiTracking.trackerType);
    end
    if config.translation.useProfileValidator
        microSignals(:,end+1) = profileMicroSignal;
        microNames{end+1} = '一维边缘相关带通';
    end
    save_motion_spectrum_figure(time,microSignals,microNames, ...
        fps,config.microVibration.bandHz, ...
        fullfile(outputDirectory,'08_micro_vibration_waveform_spectrum.png'), ...
        '微振动位移 (px)',sprintf('微振动分量（%.2f–%.2f Hz）', ...
        config.microVibration.bandHz),true);
end
processingTime.microVibrationSeconds = toc(microTimer);

%% 4. 可选 LDV/三角激光真值对比与自动时间同步
if strcmpi(config.motionModel,'rotation')
    visualSignal = absoluteAngles;
else
    switch lower(config.primaryAxis)
        case 'x', visualSignal = xDisplacement;
        otherwise, visualSignal = yDisplacement;
    end
end
[totalDominantFrequency,spectrumFrequency,spectrumAmplitude] = ...
    estimate_dominant_frequency(visualSignal,fps,frequencyRange);
% 对“振动测量”报告微振动带内主频；总位移主频仍单独保存，避免把宏观
% 运动的主峰误读成振动结果。旋转模式没有独立带通分量，沿用总位移主频。
dominantFrequency = totalDominantFrequency;
if config.microVibration.enabled && strcmpi(config.motionModel,'translation') && ...
        isfinite(vibrationDominantFrequency)
    dominantFrequency = vibrationDominantFrequency;
end
referenceRaw = nan(frameCount,1);
referenceAligned = nan(frameCount,1);
referenceLagFrames = NaN;
referenceRmse = NaN;
referenceCorrelation = NaN;
referenceSign = 1;
referenceInvalidCount = NaN;
visualVelocity = nan(frameCount,1);
visualAcceleration = nan(frameCount,1);
referenceAcceleration = nan(frameCount,1);
accelerationLowpassHz = min(config.acceleration.lowpassHz,0.95*fps/2);
referenceTimer = tic;
if config.reference.enabled
    [referenceTime,referenceValue,referenceInvalidCount] = loadReferenceData(config.reference);
    referenceValue = referenceValue*config.reference.pixelsPerUnit;
    referenceRaw = interp1(referenceTime-referenceTime(1),referenceValue,time,'linear',NaN);
    [referenceAligned,referenceLagFrames] = alignReference( ...
        referenceRaw,visualSignal,fps,config.reference);
    valid = isfinite(referenceAligned) & isfinite(visualSignal);
    if nnz(valid)>=10
        correlationMatrix = corrcoef(visualSignal(valid),referenceAligned(valid));
        referenceCorrelation = correlationMatrix(1,2);
        if referenceCorrelation<0
            referenceSign = -1;
            referenceAligned = -referenceAligned;
            referenceCorrelation = -referenceCorrelation;
        end
        referenceRmse = sqrt(mean((visualSignal(valid)-referenceAligned(valid)).^2));
    end
    save_reference_comparison_figure(time,visualSignal,referenceAligned, ...
        fps,frequencyRange,fullfile(outputDirectory,'09_visual_reference_comparison.png'), ...
        '视觉与外部真值对比','位移/角度');

    [visualVelocity,visualAcceleration] = deriveAcceleration(visualSignal,fps, ...
        accelerationLowpassHz);
    [~,referenceAcceleration] = deriveAcceleration(referenceAligned,fps, ...
        accelerationLowpassHz);
    save_reference_comparison_figure(time,visualAcceleration,referenceAcceleration, ...
        fps,frequencyRange,fullfile(outputDirectory,'10_acceleration_comparison.png'), ...
        sprintf('加速度对比（%.1f Hz 低通）',accelerationLowpassHz), ...
        '加速度 (px/s^2)');
    save_motion_spectrum_figure(time,[visualAcceleration referenceAcceleration], ...
        {'视觉加速度','LDV/激光加速度'},fps,frequencyRange, ...
        fullfile(outputDirectory,'11_acceleration_waveform_spectrum.png'), ...
        '加速度','加速度时程与频谱');
end
processingTime.referenceComparisonSeconds = toc(referenceTimer);

%% 5. 数值、配置、跟踪视频和论文式汇总输出
% 主要输出：time_history.csv/real_data_result.mat 为逐帧数值，summary.csv 为主频与
% 误差汇总，06/07/08/09/10/11 为波形、频谱和真值对比图，processing_time.csv 为耗时。
outputTimer = tic;
resultTable = table(time,xDisplacement,yDisplacement,absoluteAngles, ...
    coarseDisplacement(:,1),coarseDisplacement(:,2),roiTrajectory(:,1),roiTrajectory(:,2), ...
    roiTracking.center_xy(:,1)-roiTracking.center_xy(1,1), ...
    roiTracking.center_xy(:,2)-roiTracking.center_xy(1,2), ...
    roiTracking.bbox_xywh(:,3),roiTracking.bbox_xywh(:,4), ...
    roiTracking.scale(:,1),roiTracking.scale(:,2),roiTracking.confidence, ...
    roiTracking.valid,roiTracking.lost,roiTracking.redetect, ...
    roiTracking.hitBoundary,roiTracking.largeMotionContinuous(:,1), ...
    roiTracking.largeMotionContinuous(:,2),roiTrajectory(:,3),roiTrajectory(:,4), ...
    roiTracking.validPointCount,roiTracking.quality,roiTracking.fallbackUsed, ...
    roiTracking.templateScore,roiTracking.templateCorrectionUsed, ...
    rotationCoarseSteps,rotationCoarseValidCount,rotationCoarseMovingCount, ...
    rotationCoarseFallback, ...
    largeMotionSignal,microVibrationSignal,kltMicroSignal,profileMicroSignal, ...
    profileTotalDisplacement,profileTrackingQuality,speedRpm,speedRpmRobust, ...
    visualVelocity,visualAcceleration,referenceRaw,referenceAligned,referenceAcceleration, ...
    'VariableNames', ...
    {'time_s','x_displacement_px','y_displacement_px','angle_deg', ...
    'coarse_roi_x_px','coarse_roi_y_px','roi_x_px','roi_y_px', ...
    'track_center_x_signed_px','track_center_y_signed_px', ...
    'track_width_px','track_height_px','track_scale_x','track_scale_y', ...
    'tracking_confidence','tracking_valid','tracking_lost','redetect_used', ...
    'roi_boundary','macro_x_px','macro_y_px','roi_width_px','roi_height_px', ...
    'roi_valid_points','roi_tracking_quality','roi_fallback_used', ...
    'roi_template_score','roi_template_correction_used', ...
    'rotation_coarse_step_deg','rotation_coarse_valid_count', ...
    'rotation_coarse_moving_count','rotation_coarse_fallback_used', ...
    'large_motion_primary_px','micro_vibration_primary_px','klt_micro_candidate_px', ...
    'profile_micro_candidate_px','profile_total_displacement_px','profile_tracking_quality', ...
    'rotation_speed_rpm','rotation_speed_robust_rpm', ...
    'visual_velocity_px_s','visual_acceleration_px_s2','reference_raw', ...
    'reference_aligned','reference_acceleration_px_s2'});
writetable(resultTable,fullfile(outputDirectory,'time_history.csv'));
trackingMeasurementConsistency=struct();
if startsWith(lower(string(roiTracking.trackerType)),'rmptf')
    axisIndex=1+strcmpi(config.primaryAxis,'y');
    measured=xDisplacement; if axisIndex==2, measured=yDisplacement; end
    trackingMeasurementConsistency=rmptf.measurement_consistency( ...
        roiTracking.rawDisplacement(:,axisIndex),measured,roiTracking.quality, ...
        profileTrackingQuality,struct());
    consistencyTable=table(time,trackingMeasurementConsistency.agreement, ...
        trackingMeasurementConsistency.fusedQuality,trackingMeasurementConsistency.phaseAssistUsed, ...
        'VariableNames',{'time_s','track_phase_agreement','fused_quality','phase_assist_used'});
    writetable(consistencyTable,fullfile(outputDirectory,'tracking_measurement_consistency.csv'));
end
summaryTable = table(dominantFrequency,totalDominantFrequency, ...
    vibrationDominantFrequency,referenceLagFrames,referenceRmse, ...
    microDominantFrequency,kltDominantFrequency,profileDominantFrequency, ...
    microKltCorrelation,microReliable,microSearchBandIsUserConstrained, ...
    phaseResidualMaximumJump,string(selectedTranslationReferenceMode), ...
    medianRotationRpm,meanRotationRpm,config.rotation.bladeCount, ...
    maximumUnambiguousRpm,rotationAliasingRisk,measurementPointRadiusAdequate, ...
    measurementPointsAutoAdjusted,rotationFrequencyHz,bladePassFrequencyHz, ...
    referenceCorrelation,referenceInvalidCount, ...
    string(roiTracking.trackerType),string(roiTracking.dynamicRoiMode), ...
    roiTracking.macroTrendDiagnostics.cutoffHz, ...
    mean(double(roiTracking.valid),'omitnan'),mean(double(~roiTracking.lost),'omitnan'), ...
    nnz(roiTracking.lost),nnz(roiTracking.redetect), ...
    roiTracking.fallbackFrameCount,roiTracking.templateCorrectionFrameCount, ...
    roiTracking.boundaryFrameCount, ...
    config.reference.laserFs,config.reference.laserGraphNumber, ...
    config.reference.laserColumnNumber,config.reference.laserInvalidThreshold, ...
    'VariableNames', {'dominant_frequency_Hz','total_dominant_frequency_Hz', ...
    'vibration_dominant_frequency_Hz','reference_lag_frames', ...
    'reference_RMSE','micro_frequency_Hz','klt_frequency_Hz','profile_frequency_Hz', ...
    'micro_klt_correlation','micro_result_reliable','micro_search_band_user_constrained', ...
    'phase_residual_max_jump_px','translation_reference_mode', ...
    'median_rotation_rpm','mean_rotation_rpm','rotation_blade_count', ...
    'maximum_unambiguous_rpm','rotation_aliasing_risk', ...
    'measurement_point_radius_adequate', ...
    'measurement_points_auto_adjusted','rotation_frequency_Hz', ...
    'blade_pass_frequency_Hz', ...
    'reference_correlation','reference_invalid_samples', ...
    'tracker_type','dynamic_roi_mode','macro_trend_cutoff_Hz', ...
    'tracking_valid_fraction','tracking_recovered_fraction','tracking_lost_frames', ...
    'tracking_redetect_frames', ...
    'roi_fallback_frames','roi_template_correction_frames','roi_boundary_frames', ...
    'laserFs','LaserGraphNumber','LaserColumnNumber','LaserInvalidThreshold'});
writetable(summaryTable,fullfile(outputDirectory,'summary.csv'));
if config.writeTrackingVideo
    if strcmpi(config.motionModel,'rotation')
        frameValues = absoluteAngles; valueLabel = 'angle (deg)';
    elseif strcmpi(config.primaryAxis,'x')
        frameValues = xDisplacement; valueLabel = 'x displacement (px)';
    else
        frameValues = yDisplacement; valueLabel = 'y displacement (px)';
    end
    write_estimated_tracks_video(frames,fullfile(outputDirectory,'tracking.mp4'), ...
        min(fps,30),'Real video: M-PME',pointTracksLocal,frameValues,valueLabel);
end

processingTime.outputWritingSeconds = toc(outputTimer);
processingTime.algorithmSeconds = processingTime.videoLoadingAndRoiTrackingSeconds+ ...
    processingTime.motionEstimationSeconds+processingTime.microVibrationSeconds+ ...
    processingTime.referenceComparisonSeconds;
processingTime.totalSeconds = toc(totalTimer);
processingTime.meanAlgorithmSecondsPerFrame = processingTime.algorithmSeconds/frameCount;
processingTimeTable = struct2table(processingTime,'AsArray',true);
writetable(processingTimeTable,fullfile(outputDirectory,'processing_time.csv'));
save(fullfile(outputDirectory,'real_data_result.mat'),'config','roi','roiTrajectory', ...
    'roiTracking','processingTime','fps','time','transforms','diagnostics', ...
    'xDisplacement','yDisplacement','absoluteAngles','rawStepAngles', ...
    'integratedStepAngles','anchorAngles','anchorQuality','hubCenter', ...
    'measurementPoints','pointTracks','pointTracksLocal','dominantFrequency', ...
    'totalDominantFrequency','vibrationDominantFrequency', ...
    'spectrumFrequency','spectrumAmplitude','referenceRaw','referenceAligned', ...
    'referenceLagFrames','referenceRmse','referenceCorrelation','referenceInvalidCount', ...
    'referenceSign','largeMotionSignal','microVibrationSignal','kltMicroSignal', ...
    'profileMicroSignal','profileTotalDisplacement','profileTrackingQuality', ...
    'trackingMeasurementConsistency', ...
    'kltDominantFrequency','profileDominantFrequency','microKltCorrelation', ...
    'microReliable','microFrequencySearchBand','microSearchBandIsUserConstrained', ...
    'phaseResidualMaximumJump','selectedTranslationReferenceMode', ...
    'speedRpm','speedRpmRobust','medianRotationRpm','meanRotationRpm', ...
    'maximumUnambiguousRpm','rotationAliasingRisk','measurementPointRadiusAdequate', ...
    'measurementPointsAutoAdjusted','rotationFrequencyHz','bladePassFrequencyHz', ...
    'rotationCoarseSteps','rotationCoarseValidCount','rotationCoarseMovingCount', ...
    'rotationCoarseFallback', ...
    'microDominantFrequency','visualVelocity','visualAcceleration','referenceAcceleration', ...
    'accelerationLowpassHz');

fprintf('真实视频处理完成：%s\n',outputDirectory);
fprintf('主频 %.4f Hz；共处理 %d 帧，帧率 %.3f fps。\n', ...
    dominantFrequency,frameCount,fps);
if strcmpi(config.motionModel,'rotation')
    fprintf('中位转速 %.3f r/min（%.4f Hz），叶频 %.4f Hz；无歧义上限 %.1f r/min。\n', ...
        medianRotationRpm,rotationFrequencyHz,bladePassFrequencyHz,maximumUnambiguousRpm);
    if rotationAliasingRisk
        fprintf('警告：帧间转角接近叶片周期 Nyquist 上限，当前转速可能发生混叠。\n');
    end
end
fprintf('算法处理 %.3f s（%.5f s/帧）；总耗时 %.3f s。\n', ...
    processingTime.algorithmSeconds,processingTime.meanAlgorithmSecondsPerFrame, ...
    processingTime.totalSeconds);
if config.reference.enabled
    fprintf('外部真值对齐：lag=%g 帧，RMSE=%.5g，相关系数=%.4f。\n', ...
        referenceLagFrames,referenceRmse,referenceCorrelation);
end

%% 局部函数：读取和对齐可选外部真值
function [time,value,invalidCount] = loadReferenceData(referenceConfig)
if ~isfile(referenceConfig.filePath)
    error('找不到外部真值文件：%s',referenceConfig.filePath);
end
[~,~,extension] = fileparts(referenceConfig.filePath);
if strcmpi(extension,'.mat')
    data = load(referenceConfig.filePath);
    if ~isfield(data,referenceConfig.timeVariable) || ...
            ~isfield(data,referenceConfig.displacementVariable)
        error('MAT 文件缺少配置的时间或位移变量。');
    end
    time = double(data.(referenceConfig.timeVariable)(:));
    value = double(data.(referenceConfig.displacementVariable)(:));
else
    numericData = readmatrix(referenceConfig.filePath);
    columnNumber = referenceConfig.laserColumnNumber;
    if size(numericData,2)<columnNumber
        error('CSV/TXT 真值没有配置的第 %d 列。',columnNumber);
    end
    value = double(numericData(:,columnNumber));
    if isempty(referenceConfig.csvTimeColumn)
        time = (0:size(numericData,1)-1).' / referenceConfig.laserFs;
    else
        if size(numericData,2)<referenceConfig.csvTimeColumn
            error('CSV/TXT 真值没有配置的时间列。');
        end
        time = double(numericData(:,referenceConfig.csvTimeColumn));
    end
end
invalidMask = ~isfinite(time) | ~isfinite(value) | ...
    value <= referenceConfig.laserInvalidThreshold;
invalidCount = nnz(invalidMask);
value(invalidMask) = NaN;
% 保留无效样本在原时间轴上的位置，后续仅为分析副本插值，不篡改原始位置。
valid = isfinite(time);
time = time(valid); value = value(valid);
end

function [aligned,bestLag] = alignReference(rawReference,visualSignal,fps,referenceConfig)
aligned = nan(size(rawReference));
if referenceConfig.autoAlign
    filledReference = fillmissing(rawReference,'nearest');
    maximumLag = min(round(numel(visualSignal)/4), ...
        round(referenceConfig.maximumAlignmentLagSeconds*fps));
    alignmentVisual = detrend(visualSignal);
    alignmentReference = detrend(filledReference);
    % 对齐只使用配置频带，减少漂移和高频噪声对延迟估计的干扰；
    % 真正的输出波形仍保留原始/低通后的数值，不会被此处的滤波替换。
    if isfield(referenceConfig,'alignmentBandHz') && ...
            numel(referenceConfig.alignmentBandHz)==2
        band = referenceConfig.alignmentBandHz;
        band(1) = max(band(1),eps);
        band(2) = min(band(2),0.95*fps/2);
        if band(2)>band(1)
            [filterB,filterA] = butter(2,band/(fps/2),'bandpass');
            alignmentVisual = filtfilt(filterB,filterA,alignmentVisual);
            alignmentReference = filtfilt(filterB,filterA,alignmentReference);
        end
    end
    [correlation,lags] = xcorr(alignmentVisual,alignmentReference, ...
        maximumLag,'coeff');
    [~,index] = max(correlation); bestLag = lags(index);
else
    bestLag = round(referenceConfig.manualLagSeconds*fps);
end
if bestLag>=0
    aligned(1+bestLag:end) = rawReference(1:end-bestLag);
else
    shift = -bestLag;
    aligned(1:end-shift) = rawReference(1+shift:end);
end
end

function [velocity,acceleration] = deriveAcceleration(signal,fps,lowpassHz)
%DERIVEACCELERATION 对位移做零相位微分和低通，避免引入新的时间滞后。
signal = double(signal(:));
signal = fillmissing(signal,'nearest');
dt = 1/fps;
velocity = gradient(detrend(signal),dt);
acceleration = gradient(velocity,dt);
if lowpassHz>0 && lowpassHz<fps/2
    [filterB,filterA] = butter(2,lowpassHz/(fps/2),'low');
    acceleration = filtfilt(filterB,filterA,acceleration);
end
acceleration = acceleration-mean(acceleration,'omitnan');
end

function [largeMotion,microMotion] = separate_motion_bands(signal,fps,microConfig)
%SEPARATE_MOTION_BANDS 用零相位滤波生成带内微振动及其互补分量。
% 大运动不能再定义成“1 Hz 以下低通”：快速大运动会因此被漏报，
% 并在总位移频谱中伪装成主频。这里将带外互补项完整保留。
signal = fillmissing(double(signal(:)),'linear','EndValues','nearest');
nyquist = fps/2;
band = sort(double(microConfig.bandHz(:).'));
band(1) = max(band(1),eps);
band(2) = min(band(2),0.95*nyquist);
if band(2)<=band(1)
    error('微振动频带无效：应满足 0 < 下限 < 上限 < Nyquist。');
end
order = max(1,round(microConfig.filterOrder));
[bandB,bandA] = butter(order,band/nyquist,'bandpass');
microMotion = filtfilt(bandB,bandA,signal);
microMotion = microMotion-mean(microMotion,'omitnan');
largeMotion = signal-microMotion;
largeMotion = largeMotion-mean(largeMotion,'omitnan');
end

function save_reference_comparison_figure(time,visualSignal,referenceSignal, ...
    fps,frequencyRange,outputPath,titleText,yLabel)
%SAVE_REFERENCE_COMPARISON_FIGURE 输出归一化时域和频域对比，原始量保存在 CSV/MAT。
visualSignal = double(visualSignal(:));
referenceSignal = double(referenceSignal(:));
referenceSignal = fillmissing(referenceSignal,'linear','EndValues','nearest');
valid = isfinite(visualSignal) & isfinite(referenceSignal);
if nnz(valid)<10, return; end
visualDisplay = standardize_for_display(visualSignal(valid));
referenceDisplay = standardize_for_display(referenceSignal(valid));
[visualFrequency,visualSpectrum] = localSpectrum(visualSignal(valid),fps);
[referenceFrequency,referenceSpectrum] = localSpectrum(referenceSignal(valid),fps);
frequencyLimit = min(frequencyRange(2),fps/2);
fig = figure('Visible','off','Color','w','Position',[50 50 980 360]);
layout = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile; plot(time(valid),visualDisplay,'-','Color',[0 0.32 0.62],'LineWidth',1.1); hold on;
plot(time(valid),referenceDisplay,'--','Color',[0.85 0.20 0.18],'LineWidth',1.1);
grid on; box on; xlabel('时间 (s)'); ylabel(['归一化' yLabel]); title('时域对比');
legend('视觉 M-PME','LDV/三角光','Location','best','Box','off');
nexttile; plot(visualFrequency,visualSpectrum,'-','Color',[0 0.32 0.62],'LineWidth',1.1); hold on;
plot(referenceFrequency,referenceSpectrum,'--','Color',[0.85 0.20 0.18],'LineWidth',1.1);
grid on; box on; xlim([0 frequencyLimit]); xlabel('频率 (Hz)'); ylabel('归一化幅值');
title('频谱对比'); legend('视觉','LDV/三角光','Location','best','Box','off');
title(layout,titleText,'FontWeight','normal','FontSize',11);
set(findall(fig,'-property','FontName'),'FontName','Microsoft YaHei');
set(findall(fig,'Type','axes'),'FontSize',9,'LineWidth',0.8,'TickDir','out');
exportgraphics(fig,outputPath,'Resolution',240); close(fig);
end

function standardized = standardize_for_display(signal)
signal = signal-mean(signal,'omitnan');
scale = std(signal,0,'omitnan');
if ~isfinite(scale) || scale<=eps
    standardized=zeros(size(signal));
else
    standardized=signal/scale;
end
end

function [frequency,normalizedAmplitude] = localSpectrum(signal,fps)
signal = detrend(double(signal(:)));
window = hann(numel(signal),'periodic');
amplitude = abs(fft(signal.*window));
lastIndex = floor(numel(signal)/2)+1;
amplitude = amplitude(1:lastIndex);
frequency = (0:lastIndex-1).' * fps/numel(signal);
normalizedAmplitude = amplitude/max(max(amplitude),eps);
end
