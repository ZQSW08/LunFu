function [frames, videoInfo, roiTrajectory, tracking] = apcv_read_dynamic_roi_video( ...
    videoPath, initialRoi, maxFrames, fpsOverride, options, timeWindow)
%APCV_READ_DYNAMIC_ROI_VIDEO 先粗跟踪再低频跟随裁剪真实视频。
%
% 该函数是 AP-CV 的可选前置层：默认转到 fDSST（平移+尺度）适配器；
% 也可选择 KLT 特征点估计带符号的二维平移。第二遍只跟随低频（大运动）
% 轨迹并按整数像素裁剪固定尺寸窗口。
% 因此高频/亚像素微振动不会被“完全跟踪并消除”，仍交给 AP-CV 的
% 幅值--相位融合测量。低通和裁剪参数是实现适配，不声称是论文原文参数。

if nargin < 3 || isempty(maxFrames), maxFrames = Inf; end
if nargin < 4, fpsOverride = []; end
if nargin < 5 || isempty(options), options = struct(); end
if nargin < 6 || isempty(timeWindow), timeWindow = struct(); end
options = localDefaults(options);
if startsWith(lower(char(options.trackerType)),'rmptf')
    [frames,videoInfo,roiTrajectory,tracking] = apcv_read_dynamic_roi_video_rmptf( ...
        videoPath,initialRoi,maxFrames,fpsOverride,options,timeWindow);
    return;
end
% fDSST 是报告推荐的“平移+尺度”前端；其结果由独立适配器处理。
% 保留本文件中的 KLT 实现用于无 MEX 环境的对照和回退。
if strcmpi(char(options.trackerType),'fdsst')
    [frames,videoInfo,roiTrajectory,tracking] = apcv_read_dynamic_roi_video_fdsst( ...
        videoPath,initialRoi,maxFrames,fpsOverride,options,timeWindow);
    return;
end

reader = VideoReader(videoPath);
videoFps = reader.FrameRate;
captureFps = localWindowValue(timeWindow,'captureFps',videoFps);
captureFpsProvided = isfield(timeWindow,'captureFps') && ~isempty(timeWindow.captureFps);
if captureFpsProvided
    stride=1; processingFps=captureFps;
else
    [stride, processingFps] = localSampling(videoFps, fpsOverride);
end
firstRgb = readFrame(reader);
firstGray = localGray(firstRgb);
[imageHeight, imageWidth] = size(firstGray);
initialRoi = localClampRoi(double(initialRoi), imageWidth, imageHeight);

% maxFrames 表示送入 AP-CV 的处理帧数；跟踪仍在原始帧率上进行，
% 这样抽帧不会把相邻处理帧之间的运动误判成一次过大的跳变。
startSeconds = localWindowValue(timeWindow,'startSeconds',0);
durationSeconds = localWindowValue(timeWindow,'durationSeconds',Inf);
if ~isscalar(startSeconds)||~isfinite(startSeconds)||startSeconds<0
    error('timeWindow.startSeconds 必须是非负有限标量。');
end
if ~(isscalar(durationSeconds)&&((isfinite(durationSeconds)&&durationSeconds>0)||isinf(durationSeconds)))
    error('timeWindow.durationSeconds 必须为正数或 Inf。');
end
if ~isscalar(captureFps)||~isfinite(captureFps)||captureFps<=0
    error('timeWindow.captureFps 必须是正的有限采集帧率。');
end
startCaptureFrame = floor(startSeconds*captureFps)+1;
if captureFpsProvided
    startSourceIndex=startCaptureFrame;
else
    startSourceIndex=round((startCaptureFrame-1)*videoFps/captureFps)+1;
end
maxReadable = floor(reader.Duration*videoFps)+2;
if isfinite(durationSeconds)
    endCaptureFrame = floor((startSeconds+durationSeconds)*captureFps)+1;
    if captureFpsProvided
        endSourceIndex=min(maxReadable,endCaptureFrame);
    else
        endSourceIndex=min(maxReadable,round((endCaptureFrame-1)*videoFps/captureFps)+1);
    end
else
    endSourceIndex = maxReadable;
end
if startSourceIndex>endSourceIndex, error('timeWindow 起始时间超出视频时长。'); end
maxSourceFrames = endSourceIndex;

if ~exist('vision.PointTracker','class') && exist('vision.PointTracker','file') ~= 2
    error(['dynamicROI 需要 Computer Vision Toolbox 的 vision.PointTracker。' ...
        ' 若只运行固定 ROI 基线，请将 runConfig.dynamicROI.enabled 设为 false。']);
end

% 第一遍：KLT 粗跟踪。所有位移均保留正负号，x 向右、y 向下为正。
rawRoi = nan(maxSourceFrames,4);
rawRoi(1,:) = initialRoi;
validPointCount = zeros(maxSourceFrames,1);
quality = nan(maxSourceFrames,1);
stepDisplacement = zeros(maxSourceFrames,2);
fallbackUsed = false(maxSourceFrames,1);
currentRoi = initialRoi;
[points, pointStrength] = localDetectPoints(firstGray, currentRoi, options);
if size(points,1) < options.minimumPoints
    error('初始 ROI 内可跟踪特征点只有 %d 个，少于 minimumPoints=%d；请重新框选含纹理区域。', ...
        size(points,1), options.minimumPoints);
end
tracker = vision.PointTracker('MaxBidirectionalError', options.maximumBidirectionalError, ...
    'NumPyramidLevels', options.pyramidLevels);
initialize(tracker, points, firstGray);
previousPoints = points;
validPointCount(1) = size(points,1);
quality(1) = mean(pointStrength,'omitnan');
lastReliableStep = [0 0];
sourceCount = 1;
try
    while hasFrame(reader) && sourceCount < maxSourceFrames
        sourceCount = sourceCount + 1;
        rgb = readFrame(reader);
        gray = localGray(rgb);
        [newPoints, validity, scores] = tracker(gray);
        valid = validity & all(isfinite(newPoints),2) & all(isfinite(previousPoints),2);
        oldValid = previousPoints(valid,:);
        newValid = newPoints(valid,:);
        scoreValid = scores(valid);
        [delta, inlierMask, reliable] = localRobustTranslation(oldValid,newValid,options);
        if reliable
            newValid = newValid(inlierMask,:);
            scoreValid = scoreValid(inlierMask);
            lastReliableStep = delta;
        else
            % 短暂遮挡或低纹理时沿用衰减速度，并记录质量标志；不伪造新的观测。
            delta = options.fallbackVelocityDecay * lastReliableStep;
            fallbackUsed(sourceCount) = true;
        end
        if norm(delta) > options.maximumStepPixels
            delta = delta/norm(delta)*options.maximumStepPixels;
            fallbackUsed(sourceCount) = true;
        end
        proposedRoi = currentRoi;
        proposedRoi(1:2) = proposedRoi(1:2) + delta;
        currentRoi = localClampRoi(proposedRoi,imageWidth,imageHeight);
        rawRoi(sourceCount,:) = currentRoi;
        stepDisplacement(sourceCount,:) = delta;
        validPointCount(sourceCount) = size(newValid,1);
        if isempty(scoreValid), quality(sourceCount) = 0;
        else, quality(sourceCount) = median(scoreValid,'omitnan'); end

        needsRedetection = size(newValid,1) < options.redetectPointCount || ...
            mod(sourceCount-1, options.redetectInterval) == 0 || ~reliable;
        if needsRedetection
            [refreshedPoints,~] = localDetectPoints(gray,currentRoi,options);
            release(tracker);
            if size(refreshedPoints,1) >= options.minimumPoints
                initialize(tracker,refreshedPoints,gray);
                previousPoints = refreshedPoints;
            elseif size(newValid,1) >= options.minimumPoints
                initialize(tracker,newValid,gray);
                previousPoints = newValid;
            else
                % 允许一次短时预测，但连续丢失说明动态 ROI 不再可信，应明确中止。
                error('第 %d 个原始帧动态跟踪丢失：有效特征不足，请扩大 ROI 或降低 minimumPoints。', sourceCount);
            end
        else
            setPoints(tracker,newValid);
            previousPoints = newValid;
        end
    end
catch ME
    release(tracker);
    rethrow(ME);
end
release(tracker);
rawRoi = rawRoi(1:sourceCount,:);
validPointCount = validPointCount(1:sourceCount);
quality = quality(1:sourceCount);
stepDisplacement = stepDisplacement(1:sourceCount,:);
fallbackUsed = fallbackUsed(1:sourceCount);

rawCenter = rawRoi(:,1:2) + 0.5*rawRoi(:,3:4);
rawDisplacement = rawCenter - rawCenter(1,:);
largeMotion = localLowpass(rawDisplacement, videoFps, options.largeMotionCutoffHz);
largeMotion = largeMotion - largeMotion(1,:);
axisToken = lower(char(options.trackingAxis));
if ~any(strcmp(axisToken,{'x','y','xy','both'}))
    error('dynamicROI.trackingAxis 必须为 x、y 或 xy。');
end
if strcmp(axisToken,'x')
    largeMotion(:,2) = 0;
elseif strcmp(axisToken,'y')
    largeMotion(:,1) = 0;
end
microCandidate = rawDisplacement - largeMotion;

selectedIndices = startSourceIndex:stride:sourceCount;
if isfinite(maxFrames), selectedIndices = selectedIndices(1:min(numel(selectedIndices),floor(maxFrames))); end
if numel(selectedIndices) < 3
    error('动态 ROI 抽帧后可处理帧数不足 3 帧。');
end
selectedIndices = selectedIndices(:);
frameCount = numel(selectedIndices);

% 第二遍：只按低频趋势平移初始窗口，始终保持同一像素尺寸，避免 resize 引入相位偏差。
analysisTrajectory = repmat(initialRoi, frameCount, 1);
hitBoundary = false(frameCount,1);
for k = 1:frameCount
    proposed = initialRoi;
    proposed(1:2) = proposed(1:2) + largeMotion(selectedIndices(k),:);
    [analysisTrajectory(k,:),hitBoundary(k)] = localCenteredRoi( ...
        proposed(1:2)+0.5*proposed(3:4), initialRoi(3:4), imageWidth, imageHeight);
end

frames = zeros(initialRoi(4), initialRoi(3), frameCount, 'single');
secondReader = VideoReader(videoPath);
selectedCursor = 1;
sourceIndex = 0;
while hasFrame(secondReader) && selectedCursor <= frameCount
    sourceIndex = sourceIndex + 1;
    rgb = readFrame(secondReader);
    if sourceIndex ~= selectedIndices(selectedCursor), continue; end
    gray = localGray(rgb);
    frames(:,:,selectedCursor) = single(localFixedCrop(gray, analysisTrajectory(selectedCursor,:)));
    selectedCursor = selectedCursor + 1;
end
if selectedCursor <= frameCount
    error('第二遍动态裁剪提前结束，只读取到 %d/%d 个处理帧。', selectedCursor-1, frameCount);
end

roiTrajectory = analysisTrajectory;
tracking = struct();
tracking.trackerType = 'klt_smooth';
tracking.validPointCount = validPointCount(selectedIndices);
tracking.quality = quality(selectedIndices);
tracking.stepDisplacement = stepDisplacement(selectedIndices,:);
tracking.fallbackUsed = fallbackUsed(selectedIndices);
tracking.hitBoundary = hitBoundary;
tracking.rawCoarseDisplacement = rawDisplacement(selectedIndices,:);
tracking.largeMotionContinuous = largeMotion(selectedIndices,:);
tracking.kltMicroCandidate = microCandidate(selectedIndices,:);
tracking.coarseDisplacement = analysisTrajectory(:,1:2)-analysisTrajectory(1,1:2);
tracking.analysisRoiTrajectory = analysisTrajectory;
tracking.rawRoiTrajectory = rawRoi(selectedIndices,:);
tracking.selectedSourceIndices = selectedIndices;
tracking.fallbackFrameCount = nnz(tracking.fallbackUsed);
tracking.boundaryFrameCount = nnz(hitBoundary);
tracking.largeMotionCutoffHz = options.largeMotionCutoffHz;
tracking.trackingAxis = char(options.trackingAxis);

videoInfo.path = videoPath;
videoInfo.videoFps = videoFps;
videoInfo.processingFps = processingFps;
videoInfo.frameCount = frameCount;
videoInfo.requestedMaxFrames = maxFrames;
videoInfo.frameIndices = selectedIndices;
videoInfo.time = (selectedIndices-1)/videoFps;
videoInfo.originalWidth = imageWidth;
videoInfo.originalHeight = imageHeight;
videoInfo.roi = initialRoi;
videoInfo.durationSeconds = videoInfo.time(end)-videoInfo.time(1);
videoInfo.windowStartSeconds = startSeconds;
videoInfo.windowDurationSeconds = durationSeconds;
videoInfo.captureFps = captureFps;
if captureFpsProvided
    videoInfo.captureFrameIndices=selectedIndices;
else
    videoInfo.captureFrameIndices=round((selectedIndices-1)*captureFps/videoFps)+1;
end
videoInfo.captureTime = (videoInfo.captureFrameIndices-1)/captureFps;
if captureFpsProvided, videoInfo.time = videoInfo.captureTime; end
end

function value = localWindowValue(timeWindow,name,defaultValue)
if isstruct(timeWindow)&&isfield(timeWindow,name)&&~isempty(timeWindow.(name))
    value=double(timeWindow.(name));
else
    value=defaultValue;
end
end

function options = localDefaults(options)
defaults = struct('trackerType','klt_smooth','fdsstRoot', ...
    fullfile(fileparts(fileparts(mfilename('fullpath'))),'third_party','fdsst_sunjiajian'), ...
    'maximumPoints',160,'minimumPoints',6,'redetectPointCount',15, ...
    'redetectInterval',20,'minimumQuality',0.005,'maximumBidirectionalError',2, ...
    'pyramidLevels',4,'outlierFloorPixels',1.5,'maximumStepPixels',120, ...
    'fallbackVelocityDecay',0.75,'largeMotionCutoffHz',1,'trackingAxis','xy', ...
    'mode','integer_macro','targetBandHz',[],'phaseCrosslineEnabled',false, ...
    'macroTrendWindowSeconds',0.5);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k}) || isempty(options.(names{k})), options.(names{k}) = defaults.(names{k}); end
end
end

function [stride,processingFps] = localSampling(videoFps,fpsOverride)
if isempty(fpsOverride), stride = 1; processingFps = videoFps; return; end
if ~isscalar(fpsOverride) || ~isfinite(fpsOverride) || fpsOverride<=0 || fpsOverride>videoFps
    error('fpsOverride 必须在 (0, %.6g] 内。', videoFps);
end
stride = max(1,round(videoFps/fpsOverride));
processingFps = videoFps/stride;
if abs(processingFps-fpsOverride)>max(0.01,0.01*fpsOverride)
    error('当前入口只接受整数抽帧比：原始 %.6g Hz，目标 %.6g Hz 不匹配。',videoFps,fpsOverride);
end
end

function [points,strength] = localDetectPoints(gray,roi,options)
fp = detectMinEigenFeatures(gray,'ROI',round(roi),'MinQuality',options.minimumQuality);
fp = fp.selectStrongest(options.maximumPoints);
points = fp.Location; strength = fp.Metric;
end

function [delta,inlierMask,reliable] = localRobustTranslation(oldPoints,newPoints,options)
delta = [0 0]; inlierMask = false(size(oldPoints,1),1);
reliable = size(oldPoints,1)>=options.minimumPoints;
if ~reliable, return; end
steps = newPoints-oldPoints; centre = median(steps,1);
deviation = hypot(steps(:,1)-centre(1),steps(:,2)-centre(2));
scale = 1.4826*median(abs(deviation-median(deviation)));
inlierMask = deviation <= max(options.outlierFloorPixels,3*scale);
reliable = nnz(inlierMask)>=options.minimumPoints;
if reliable, delta = median(steps(inlierMask,:),1); end
end

function trajectory = localLowpass(trajectory,fps,cutoffHz)
if cutoffHz<=0, return; end
window = max(5,2*floor(0.5*fps/cutoffHz)+1);
window = min(window,2*floor((size(trajectory,1)-1)/2)+1);
if window<3, return; end
for axis = 1:size(trajectory,2)
    column = trajectory(:,axis);
    column = smoothdata(column,'movmedian',window);
    trajectory(:,axis) = smoothdata(column,'movmean',window);
end
end

function [roi,hitBoundary] = localCenteredRoi(center,roiSize,imageWidth,imageHeight)
unclamped = [center-0.5*roiSize,roiSize];
roi = localClampRoi(unclamped,imageWidth,imageHeight);
hitBoundary = any(abs(roi(1:2)-unclamped(1:2))>0.25);
end

function crop = localFixedCrop(gray,roi)
x = round(roi(1)); y = round(roi(2)); w = round(roi(3)); h = round(roi(4));
crop = gray(y:y+h-1,x:x+w-1);
end

function roi = localClampRoi(roi,imageWidth,imageHeight)
roi(3) = min(max(round(roi(3)),2),imageWidth-1);
roi(4) = min(max(round(roi(4)),2),imageHeight-1);
roi(1) = min(max(round(roi(1)),1),imageWidth-roi(3)+1);
roi(2) = min(max(round(roi(2)),1),imageHeight-roi(4)+1);
end

function gray = localGray(rgb)
if size(rgb,3)==3, gray = rgb2gray(rgb); else, gray = rgb; end
end
