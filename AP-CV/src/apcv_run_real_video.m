function output = apcv_run_real_video(runConfig)
%APCV_RUN_REAL_VIDEO 真实视频入口的流程编排函数。
% 论文专属逻辑仍由 apcv_calibrate_model/apcv_estimate_sequence 实现。

required = {'projectRoot','videoPath','outputDirectory','outputName','roi', ...
    'maxFrames','fpsOverride','gammaMmPerPixel','writeTrackingVideo', ...
    'truthPath','truthTimeColumn','truthDisplacementColumn','truthUnits', ...
    'method','output'};
for i = 1:numel(required)
    if ~isfield(runConfig, required{i})
        error('真实视频配置缺少字段：%s', required{i});
    end
end
if isempty(runConfig.videoPath) || ~isfile(runConfig.videoPath)
    error(['请先在 scripts/run_real_video.m 顶部设置有效的 videoPath。' ...
        ' 当前路径不存在或为空：%s'], char(string(runConfig.videoPath)));
end
direction = apcv_normalize_direction(runConfig.method.direction);
if strcmp(direction, 'horizontal')
    directionToken = 'x';
else
    directionToken = 'y';
end
if ~strcmpi(runConfig.method.referenceFrame, 'first')
    error('当前 AP-CV 入口固定使用第一帧作为参考；referenceFrame 必须为 first。');
end

projectRoot = runConfig.projectRoot;
assertOutputInsideProject(runConfig.outputDirectory, projectRoot);

% 该函数也可以被其他脚本直接调用，因此不能只依赖入口脚本预先设置的路径。
% 默认配置位于 configs/，这里显式加入路径并检查文件是否存在。
configPath = fullfile(projectRoot, 'configs', 'apcv_default_config.m');
if ~isfile(configPath)
    error('找不到 AP-CV 默认配置：%s', configPath);
end
addpath(fileparts(configPath));

% 首帧 ROI 选择在任何输出清理之前执行；取消时不触碰上一轮结果。
[roi, firstFrame, firstCrop, cancelled] = apcv_select_video_roi( ...
    runConfig.videoPath, runConfig.roi, ...
    '');
if cancelled
    output.cancelled = true;
    fprintf('ROI selection cancelled; no output directory was modified.\n');
    return;
end

outputDirectory = prepareOutputDirectory(runConfig.outputDirectory, ...
    runConfig.output.clearPreviousResults);
timeWindow = localTimeWindowDefaults(runConfig);
% 可选动态 ROI 前置层：只估计低频大运动并保持固定尺寸裁剪，
% AP-CV 后续标定、幅值估计和相位残差估计仍使用同一套代码。
% 默认关闭以便与固定 ROI baseline 直接对照；启用后会额外返回追踪质量元数据。
dynamicROI = localDynamicDefaults(runConfig);
if dynamicROI.enabled
    if isfield(runConfig,'writeTrackingDiagnostics') && runConfig.writeTrackingDiagnostics
        dynamicROI.diagnosticsDirectory=fullfile(outputDirectory,'rmptf_diagnostics');
    else
        dynamicROI.diagnosticsDirectory='';
    end
    [frames, videoInfo, roiTrajectory, tracking] = apcv_read_dynamic_roi_video( ...
        runConfig.videoPath, roi, runConfig.maxFrames, runConfig.fpsOverride, dynamicROI, timeWindow);
else
    [frames, videoInfo] = apcv_read_real_video(runConfig.videoPath, roi, ...
        runConfig.maxFrames, runConfig.fpsOverride, timeWindow);
    roiTrajectory = repmat(roi, videoInfo.frameCount, 1);
    tracking = struct('trackerType','disabled','analysisRoiTrajectory',roiTrajectory, ...
        'coarseDisplacement',zeros(videoInfo.frameCount,2), ...
        'rawCoarseDisplacement',zeros(videoInfo.frameCount,2), ...
        'largeMotionContinuous',zeros(videoInfo.frameCount,2), ...
        'kltMicroCandidate',zeros(videoInfo.frameCount,2), ...
        'hitBoundary',false(videoInfo.frameCount,1), ...
        'quality',ones(videoInfo.frameCount,1), ...
        'validPointCount',nan(videoInfo.frameCount,1), ...
        'fallbackUsed',false(videoInfo.frameCount,1));
end

cfg = apcv_default_config(projectRoot);
cfg.imageSize = [size(frames,1), size(frames,2)];
cfg.direction = direction;
maxHeight = floor(log2(min(cfg.imageSize))) - 2;
if maxHeight < 1
    error('ROI 尺寸 %d x %d 不足以构建复数金字塔。', cfg.imageSize(2), cfg.imageSize(1));
end
cfg.pyramidHeight = min(runConfig.method.pyramidHeight, maxHeight);
cfg.pyramidLevels = 1:cfg.pyramidHeight;
cfg.pyramidOrder = runConfig.method.pyramidOrder;
cfg.orientationBand = runConfig.method.orientationBand;
cfg.maxCoarseLag = runConfig.method.maxCoarseLag;
cfg.calibrationMaxFrames = min(runConfig.method.calibrationMaxFrames, videoInfo.frameCount);
cfg.verbose = runConfig.verbose;

physicalScaleProvided = ~isempty(runConfig.gammaMmPerPixel);
if physicalScaleProvided
    if ~isscalar(runConfig.gammaMmPerPixel) || ~isfinite(runConfig.gammaMmPerPixel) || runConfig.gammaMmPerPixel <= 0
        error('gammaMmPerPixel 必须是正的有限标量。');
    end
    gamma = runConfig.gammaMmPerPixel;
else
    gamma = 1; % 仅用于保留像素数值；不在输出中标记为毫米。
end

model = apcv_calibrate_model(frames, gamma, cfg);
result = apcv_estimate_sequence(frames, model, cfg);
if dynamicROI.enabled
    [result,tracking.pyramidGuidance] = apcv_apply_tracking_reliability( ...
        result,model,tracking,dynamicROI.adaptivePyramidEnabled);
end

if dynamicROI.enabled
    % 动态裁剪会把低频大运动移到 ROI 坐标系外；按报告建议，
    % 全局位移 = 动态 ROI 整数裁剪位移 + AP-CV 在裁剪帧上的局部残差。
    % 保留 *_apcvResidualPx 字段，便于区分“测量残差”和“全局结果”。
    axisIndex = 1 + strcmp(direction,'vertical');
    dynamicCoarse = tracking.coarseDisplacement(:,axisIndex);
    result.apcvResidualPx = result.proposedPx;
    % 明确区分局部微振动残差与恢复到原图坐标的总位移。
    % proposedPx 仍保留全局位移，vibrationResidualPx 才是频谱/振动测量信号。
    result.vibrationResidualPx = result.proposedPx;
    result.apcvAmplitudeOnlyPx = result.amplitudeOnlyPx;
    result.dynamicRoiCoarsePx = dynamicCoarse;
    result.globalCoarsePx = result.coarsePx + dynamicCoarse;
    result.coarsePx = result.globalCoarsePx;
    result.proposedPx = dynamicCoarse + result.apcvResidualPx;
    result.amplitudeOnlyPx = dynamicCoarse + result.apcvAmplitudeOnlyPx;
    result.existingScalePx = dynamicCoarse + result.existingScalePx;
    result.allPixelsPx = dynamicCoarse + result.allPixelsPx;
    result.amplitudeMaskPx = dynamicCoarse + result.amplitudeMaskPx;
    result.byLevelPx = result.byLevelPx + dynamicCoarse;
    result.byLevelMm = gamma * result.byLevelPx;
    result.proposedMm = gamma * result.proposedPx;
    result.vibrationResidualMm = gamma * result.vibrationResidualPx;
    result.amplitudeOnlyMm = gamma * result.amplitudeOnlyPx;
    result.existingScaleMm = gamma * result.existingScalePx;
    result.allPixelsMm = gamma * result.allPixelsPx;
    result.amplitudeMaskMm = gamma * result.amplitudeMaskPx;
    result.proposedPxValidOnly = result.proposedPx;
    result.proposedPxValidOnly(~tracking.valid(:)) = NaN;
    tracking.measurementConsistency=rmptf.measurement_consistency( ...
        tracking.rawDisplacement(:,axisIndex),result.proposedPx,tracking.quality, ...
        double(tracking.valid),struct());
end

% 固定区域无法恢复已经移出画面的目标。这里仅做边界风险提示，不擅自改变论文的固定 ROI 假设。
roiOverflow = assessRoiOverflow(result.proposedPx, roi, cfg.direction, runConfig.method);
if roiOverflow.flag
    message = sprintf(['估计位移已达到 ROI %s 尺寸的 %.1f%%，目标可能接近或离开框选区域。' ...
        ' 请增大 ROI、重新框选或分段处理视频。'], roiOverflow.axis, ...
        100*roiOverflow.maxFraction);
    if strcmpi(roiOverflow.policy, 'error')
        error('APCV:PossibleRoiOverflow', '%s', message);
    else
        warning('APCV:PossibleRoiOverflow', '%s', message);
    end
end

truth = loadOptionalTruth(runConfig, videoInfo.time, physicalScaleProvided);
metrics = struct();
if truth.available
    if strcmpi(truth.units, 'mm')
        metrics = apcv_compute_metrics(result.proposedMm, truth.displacement);
    else
        metrics = apcv_compute_metrics(result.proposedPx, truth.displacement);
    end
end

output.cancelled = false;
output.runConfig = runConfig;
output.cfg = cfg;
output.videoInfo = videoInfo;
output.roi = roi;
output.dynamicROI = dynamicROI;
output.timeWindow = timeWindow;
output.roiTrajectory = roiTrajectory;
output.tracking = tracking;
output.firstFrameSize = size(firstFrame);
output.firstCropSize = size(firstCrop);
output.model = model;
output.result = result;
output.truth = truth;
output.metrics = metrics;
output.physicalScaleProvided = physicalScaleProvided;
% 对外保存用户熟悉的 x/y；cfg.direction 保留内部兼容名称。
output.direction = directionToken;
output.roiOverflow = roiOverflow;
output.outputDirectory = outputDirectory;
output.status = 'completed';

apcv_write_real_results(output, outputDirectory, runConfig.outputName);
if runConfig.writeTrackingVideo
    trackingPath = fullfile(outputDirectory, [runConfig.outputName '_tracking.avi']);
    try
        apcv_write_real_tracking_video(frames, result, trackingPath, ...
            videoInfo.processingFps, physicalScaleProvided, cfg.direction, ...
            runConfig.videoPath, videoInfo.frameIndices, roiTrajectory, tracking);
        output.trackingVideoPath = trackingPath;
    catch ME
        output.trackingVideoPath = '';
        warning('APCV:TrackingVideoWriteFailed', ...
            '跟踪视频写入失败，但 CSV/MAT/图形已保留：%s', ME.message);
    end
end
save(fullfile(outputDirectory, [runConfig.outputName '_run.mat']), '-struct', 'output', '-v7.3');

fprintf('真实视频处理完成：%d 帧，处理帧率 %.6g Hz，选用金字塔第 %d 层。\n', ...
    videoInfo.frameCount, videoInfo.processingFps, model.selectedLevel);
if truth.available
    fprintf('真值对比（%s）：RMSE = %.6g。\n', truth.units, metrics.rmse);
elseif ~physicalScaleProvided
    fprintf('未提供真值或物理尺度：当前输出仅为 pixel 单位。\n');
end

function dynamicROI = localDynamicDefaults(runConfig)
% 入口兼容：旧版 runConfig 没有 dynamicROI 字段时仍运行固定 ROI。
dynamicROI = struct('enabled',false,'trackerType','rmptf', ...
    'fdsstRoot',fullfile(runConfig.projectRoot,'third_party','fdsst_sunjiajian'), ...
    'trackingAxis','xy','largeMotionCutoffHz',1,'maximumPoints',160, ...
    'minimumPoints',6,'redetectPointCount',15,'redetectInterval',20, ...
    'minimumQuality',0.005,'maximumBidirectionalError',2,'pyramidLevels',4, ...
    'outlierFloorPixels',1.5,'maximumStepPixels',120,'fallbackVelocityDecay',0.75, ...
    'mode','integer_macro','targetBandHz',[],'phaseCrosslineEnabled',false, ...
    'macroTrendWindowSeconds',0.5,'adaptivePyramidEnabled',true);
if isfield(runConfig,'dynamicROI') && ~isempty(runConfig.dynamicROI)
    supplied = runConfig.dynamicROI;
    names = fieldnames(supplied);
    for k = 1:numel(names), dynamicROI.(names{k}) = supplied.(names{k}); end
end
if ~islogical(dynamicROI.enabled) && ~(isnumeric(dynamicROI.enabled) && isscalar(dynamicROI.enabled))
    error('dynamicROI.enabled 必须是 true 或 false。');
end
dynamicROI.enabled = logical(dynamicROI.enabled);
if ~isfield(dynamicROI,'trackerType') || isempty(dynamicROI.trackerType)
    dynamicROI.trackerType = 'rmptf';
end
if ~any(strcmpi(char(dynamicROI.trackerType),{'rmptf','rmptf_crossline','rmptf_fdsst', ...
        'rmptf_fdsst_crossline','fdsst','klt_smooth'}))
    error('dynamicROI.trackerType 请填写 rmptf、rmptf_crossline、rmptf_fdsst、fdsst 或 klt_smooth。');
end
end

function timeWindow = localTimeWindowDefaults(runConfig)
% 时间窗口用“原视频时间秒”定义；抽帧后仍按实际 source frame index 计算，
% 不把 100 Hz、25 Hz 或 30 Hz 写死在算法中。
timeWindow = struct('startSeconds',0,'durationSeconds',Inf,'captureFps',[]);
if isfield(runConfig,'captureFps') && ~isempty(runConfig.captureFps)
    timeWindow.captureFps = runConfig.captureFps;
end
if isfield(runConfig,'timeWindow') && ~isempty(runConfig.timeWindow)
    supplied = runConfig.timeWindow;
    names = fieldnames(supplied);
    for k = 1:numel(names), timeWindow.(names{k}) = supplied.(names{k}); end
end
timeWindow.startSeconds = double(timeWindow.startSeconds);
timeWindow.durationSeconds = double(timeWindow.durationSeconds);
if isempty(timeWindow.captureFps)
    timeWindow.captureFps = [];
else
    timeWindow.captureFps = double(timeWindow.captureFps);
    if ~isscalar(timeWindow.captureFps) || ~isfinite(timeWindow.captureFps) || timeWindow.captureFps <= 0
        error('captureFps 必须是正的有限采集帧率。');
    end
end
if ~isscalar(timeWindow.startSeconds) || ~isfinite(timeWindow.startSeconds) || timeWindow.startSeconds < 0
    error('timeWindow.startSeconds 必须是非负有限秒数。');
end
if ~(isscalar(timeWindow.durationSeconds) && ...
        ((isfinite(timeWindow.durationSeconds) && timeWindow.durationSeconds > 0) || isinf(timeWindow.durationSeconds)))
    error('timeWindow.durationSeconds 必须为正秒数或 Inf。');
end
end
end

function diagnostic = assessRoiOverflow(displacementPx, roi, direction, method)
% 以位移/ROI 对应边长的比例给出保守提示；这不是目标分割或真正越界判定。
diagnostic = struct('flag', false, 'axis', 'Y', 'maxFraction', 0, ...
    'thresholdFraction', 0.40, 'policy', 'warn', 'maxDisplacementPx', 0);
if isfield(method, 'roiOverflowPolicy') && ~isempty(method.roiOverflowPolicy)
    diagnostic.policy = lower(char(method.roiOverflowPolicy));
end
if ~any(strcmp(diagnostic.policy, {'warn', 'error', 'ignore'}))
    error('roiOverflowPolicy 必须为 warn、error 或 ignore。');
end
if isfield(method, 'roiOverflowFraction') && ~isempty(method.roiOverflowFraction)
    diagnostic.thresholdFraction = method.roiOverflowFraction;
end
if ~isscalar(diagnostic.thresholdFraction) || ~isfinite(diagnostic.thresholdFraction) || ...
        diagnostic.thresholdFraction <= 0 || diagnostic.thresholdFraction >= 1
    error('roiOverflowFraction 必须位于 (0,1) 内。');
end
if strcmpi(direction, 'horizontal')
    axisLength = roi(3); diagnostic.axis = 'X';
else
    axisLength = roi(4); diagnostic.axis = 'Y';
end
finiteDisplacement = abs(double(displacementPx(isfinite(displacementPx))));
if isempty(finiteDisplacement)
    return;
end
diagnostic.maxDisplacementPx = max(finiteDisplacement);
diagnostic.maxFraction = diagnostic.maxDisplacementPx / axisLength;
diagnostic.flag = diagnostic.maxFraction >= diagnostic.thresholdFraction && ...
    ~strcmp(diagnostic.policy, 'ignore');
end

function outputDirectory = prepareOutputDirectory(requested, clearPrevious)
outputDirectory = char(requested);
if exist(outputDirectory, 'dir')
    if clearPrevious
        rmdir(outputDirectory, 's');
        mkdir(outputDirectory);
    else
        stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        outputDirectory = fullfile(outputDirectory, ['run_' stamp]);
        mkdir(outputDirectory);
    end
else
    mkdir(outputDirectory);
end
end

function assertOutputInsideProject(outputDirectory, projectRoot)
root = normalizePath(fullfile(projectRoot, 'outputs'));
candidate = normalizePath(outputDirectory);
if ~startsWith(candidate, [root filesep], 'IgnoreCase', true)
    error('outputDirectory 必须位于当前 AP-CV 工程的 outputs 子目录内。');
end
end

function value = normalizePath(pathValue)
value = char(java.io.File(char(pathValue)).getAbsoluteFile().toPath().normalize().toString());
value = strrep(value, '/', filesep);
end

function truth = loadOptionalTruth(runConfig, processingTime, physicalScaleProvided)
truth.available = false;
truth.units = lower(char(runConfig.truthUnits));
truth.time = [];
truth.displacement = [];
if isempty(runConfig.truthPath)
    return;
end
if ~isfile(runConfig.truthPath)
    error('truthPath 不存在：%s', runConfig.truthPath);
end
if strcmpi(truth.units, 'mm') && ~physicalScaleProvided
    error('truthUnits=mm 时必须同时提供 gammaMmPerPixel。');
end
tableValue = readtable(runConfig.truthPath);
if ~ismember(runConfig.truthTimeColumn, tableValue.Properties.VariableNames) || ...
        ~ismember(runConfig.truthDisplacementColumn, tableValue.Properties.VariableNames)
    error('truth CSV 缺少指定列：%s, %s。', runConfig.truthTimeColumn, runConfig.truthDisplacementColumn);
end
sourceTime = tableValue.(runConfig.truthTimeColumn);
sourceDisplacement = tableValue.(runConfig.truthDisplacementColumn);
sourceTime = double(sourceTime(:)); sourceDisplacement = double(sourceDisplacement(:));
valid = isfinite(sourceTime) & isfinite(sourceDisplacement);
if nnz(valid) < 2 || any(diff(sourceTime(valid)) <= 0)
    error('truth CSV 时间列必须至少有两个严格递增的有限样本。');
end
truth.time = processingTime(:);
truth.displacement = interp1(sourceTime(valid), sourceDisplacement(valid), ...
    processingTime(:), 'linear', NaN);
truth.available = any(isfinite(truth.displacement));
end
