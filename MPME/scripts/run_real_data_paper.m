%RUN_REAL_DATA_PAPER 论文式固定 ROI 真实视频复现入口。
% 本文件独立列出输入、输出、M-PME/PNL、频谱、加速度和可选 LDV 配置。
% 与动态入口相比，这里不设置也不调用大运动前端跟踪；测量后端保持同一套实现。
% ROI 为空时会在首帧显示图像，拖动矩形并双击确认。
% 本文件采用 UTF-8 中文注释，请勿用 ANSI/GBK 编码另存。

close all; clearvars; clc; warning off;
totalTimer = tic;
processingTime = struct();

%% 1. 工程路径与用户配置
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot,'src'));

config.videoPath = 'C:\0819\4-25mvpp-static.avi'; % 输入视频
config.outputDirectory = 'D:\LunFu\MPME\outputs\paper\4-25mvpp-static'; % 输出目录
config.outputName = '4-25mvpp-static-paper';              % 输出名称
config.motionModel = 'translation';        % 'translation' 或 'rotation'
config.roi = [];                         % 留空可交互框选；也可回填 [x y width height]
config.maxFrames = 1800;                % 最多读取帧数；Inf 表示全部
config.fpsOverride = [];                  % 留空使用视频元数据
config.referenceMode = 'fixed';       % 兼容旧配置；平移: fixed   旋转: adjacent
config.primaryAxis = 'x';                % 与激光真值对比的视觉分量：'x'、'y' 或 'angle'
config.frequencyRangeHz = [0.05 50];      % 频谱主峰搜索范围
config.output.clearPreviousResults = true; % 同一目录每次只保留本次运行生成的文件

% 论文基线使用固定首帧 ROI；不设置前端跟踪器和动态 ROI。

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
config.rotation.useHybridCoarsePhase = false; % 论文基线不加入粗跟踪前端
config.rotation.residualLevels = 2;       % 粗转角对齐后只需处理小残差
config.rotation.sampleStep = 4;
config.rotation.directions = [0 45 90 135]; % 论文式四方向 Gabor 约束
config.rotation.analysisInnerRadiusPixels = 8;
config.rotation.analysisOuterScale = 1.15; % 相对最远测点半径，自动形成转子掩膜

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
config.microVibration.bandHz = [2 30];    % 按实验预期频率修改，例如 6.6 Hz 包含在内
config.microVibration.frequencySearchBandHz = []; % 已知频率时建议填窄带，如 [5 9]
config.microVibration.filterOrder = 3;
config.microVibration.minimumConsensusCorrelation = 0.35;
config.microVibration.maximumFrequencyDifferenceHz = 0.75;

if isempty(config.videoPath)
    fprintf(['尚未填写 config.videoPath。请在 run_real_data_paper.m 顶部只配置一个视频，\n' ...
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
[frames,videoFps] = load_video_gray(config.videoPath,config.maxFrames,roi);
frameCount = size(frames,3);
roiTrajectory = repmat(double(roi),frameCount,1);
% 固定 ROI 不调用前端跟踪；以下记录仅用于兼容统一 MAT/CSV 字段。
roiTracking = struct('coarseDisplacement',zeros(frameCount,2), ...
    'trackerType','fixed','frontTrackerType','fixed', ...
    'frontTrackerCallCount',0,'frontTrackerOnly',true, ...
    'dynamicRoiMode','fixed', ...
    'validPointCount',nan(frameCount,1),'quality',nan(frameCount,1), ...
    'fallbackUsed',false(frameCount,1),'hitBoundary',false(frameCount,1), ...
    'rawCoarseDisplacement',zeros(frameCount,2), ...
    'largeMotionContinuous',zeros(frameCount,2), ...
    'kltMicroCandidate',nan(frameCount,2), ...
    'templateScore',nan(frameCount,1), ...
    'templateCorrectionUsed',false(frameCount,1), ...
    'redetectionUsed',false(frameCount,1), ...
    'rawRoiTrajectory',roiTrajectory,'bbox_xywh',roiTrajectory, ...
    'center_xy',roiTrajectory(:,1:2)+0.5*roiTrajectory(:,3:4), ...
    'scale',ones(frameCount,2),'confidence',nan(frameCount,1), ...
    'valid',true(frameCount,1),'lost',false(frameCount,1), ...
    'redetect',false(frameCount,1), ...
    'fallbackFrameCount',0,'templateCorrectionFrameCount',0, ...
    'boundaryFrameCount',0,'previewWritingSeconds',0, ...
    'expectedCoarseDisplacement',zeros(frameCount,2), ...
    'macroTrendDiagnostics',struct('mode','fixed','cutoffHz',0), ...
    'macro',struct('xy',zeros(frameCount,2), ...
        'microCandidate',nan(frameCount,2)), ...
    'crop',struct('origin_xy',roiTrajectory(:,1:2), ...
        'bbox_xywh',roiTrajectory,'valid',true(frameCount,1)));
loadingElapsed = toc(loadingTimer);
processingTime.dynamicRoiPreviewVideoSeconds = 0;
processingTime.videoLoadingAndRoiTrackingSeconds = loadingElapsed;
if isempty(config.fpsOverride), fps = videoFps; else, fps = config.fpsOverride; end
frameCount = size(frames,3);
time = (0:frameCount-1).'/fps;
frequencyRange = [max(0,config.frequencyRangeHz(1)) ...
    min(fps/2,config.frequencyRangeHz(2))];

params = config.mpme;
params.model = 'affine';
params.cacheFixedReference = config.performance.cacheFixedReference;
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
    else
        primarySignalForSeparation = xDisplacement;
    end
    [largeMotionSignal,microVibrationSignal] = separate_motion_bands( ...
        primarySignalForSeparation,fps,config.microVibration);
    if config.translation.useProfileValidator
        [~,profileMicroSignal] = separate_motion_bands( ...
            profileTotalDisplacement,fps,config.microVibration);
    end
    [microDominantFrequency,~,~] = estimate_dominant_frequency( ...
        microVibrationSignal,fps,microFrequencySearchBand);
    vibrationDominantFrequency = microDominantFrequency;
    if config.translation.useProfileValidator
        [profileDominantFrequency,~,~] = estimate_dominant_frequency( ...
            profileMicroSignal,fps,microFrequencySearchBand);
    end
    % 固定 ROI 没有前端轨迹可供共识校验，可靠度只表示 M-PME 成功得到主频。
    microReliable = isfinite(microDominantFrequency);
    microSignals = microVibrationSignal;
    microNames = {'M-PME 最终微振动'};
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

%% 5. 数值、配置和论文式汇总输出
% 主要输出：time_history.csv/real_data_result.mat 为逐帧数值，summary.csv 为主频与
% 误差汇总，06/07/08/09/10/11 为波形、频谱和真值对比图，processing_time.csv 为耗时。
% 论文入口不生成动态 ROI 视频；CSV/MAT 中的 fixed 轨迹字段仅用于统一字段兼容。
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
