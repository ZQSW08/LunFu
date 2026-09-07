function [frames,fps,roiTrajectory,tracking] = load_video_gray_follow_roi( ...
    videoPath,maxFrames,initialRoi,options,previewPath)
%LOAD_VIDEO_GRAY_FOLLOW_ROI 用 KLT 特征粗跟踪移动 ROI，并返回稳定后的灰度序列。
% 粗跟踪只负责把目标留在视野中；后续亚像素位移/转角仍由 M-PME 估计。

if nargin < 2 || isempty(maxFrames), maxFrames = Inf; end
if nargin < 4 || isempty(options), options = struct(); end
if nargin < 5, previewPath = ''; end
options = localDefaults(options);

reader = VideoReader(videoPath);
fps = reader.FrameRate;
estimatedCount = min(maxFrames,max(1,floor(reader.Duration*fps)));
firstRgb = readFrame(reader);
firstGray = localGray(firstRgb);
[imageHeight,imageWidth] = size(firstGray);
currentRoi = localClampRoi(double(initialRoi),imageWidth,imageHeight);

firstCrop = imcrop(firstGray,round(currentRoi));
frames = zeros(size(firstCrop,1),size(firstCrop,2),estimatedCount,'single');
frames(:,:,1) = single(firstCrop);
roiTrajectory = nan(estimatedCount,4);
roiTrajectory(1,:) = round(currentRoi);
validPointCount = zeros(estimatedCount,1);
trackingQuality = nan(estimatedCount,1);
stepDisplacement = zeros(estimatedCount,2);
hitBoundary = false(estimatedCount,1);
fallbackUsed = false(estimatedCount,1);

[points,pointStrength] = localDetectPoints(firstGray,currentRoi,options);
if size(points,1)<options.minimumPoints
    error(['所选 ROI 内只有 %d 个可跟踪特征点，至少需要 %d 个。' ...
        '请扩大 ROI 并覆盖目标表面的文字、纹理或角点。'], ...
        size(points,1),options.minimumPoints);
end
tracker = vision.PointTracker('MaxBidirectionalError', ...
    options.maximumBidirectionalError,'NumPyramidLevels',options.pyramidLevels);
initialize(tracker,points,firstGray);
previousPoints = points;
validPointCount(1) = size(points,1);
trackingQuality(1) = mean(pointStrength,'omitnan');

writePreview = ~isempty(previewPath);
previewWritingSeconds = 0;
if writePreview
    writer = VideoWriter(previewPath,'MPEG-4');
    writer.FrameRate = min(fps,options.previewFps);
    writer.Quality = 90;
    open(writer);
    previewTimer = tic;
    writeVideo(writer,localAnnotate(firstRgb,currentRoi,points,1,estimatedCount, ...
        size(points,1),trackingQuality(1),false));
    previewWritingSeconds = previewWritingSeconds+toc(previewTimer);
end

frameIndex = 1;
lastReliableStep = [0 0];
try
    while hasFrame(reader) && frameIndex < estimatedCount
        frameIndex = frameIndex+1;
        rgb = readFrame(reader);
        gray = localGray(rgb);
        [newPoints,validity,scores] = tracker(gray);
        valid = validity & all(isfinite(newPoints),2) & all(isfinite(previousPoints),2);
        oldValid = previousPoints(valid,:);
        newValid = newPoints(valid,:);
        scoreValid = scores(valid);

        [delta,inlierMask,reliable] = localRobustTranslation( ...
            oldValid,newValid,options);
        if reliable
            newValid = newValid(inlierMask,:);
            scoreValid = scoreValid(inlierMask);
            lastReliableStep = delta;
        else
            % 短暂遮挡时沿用衰减速度预测；记录 fallback，便于结果审计。
            delta = options.fallbackVelocityDecay*lastReliableStep;
            fallbackUsed(frameIndex) = true;
        end
        if norm(delta)>options.maximumStepPixels
            delta = delta/norm(delta)*options.maximumStepPixels;
            fallbackUsed(frameIndex) = true;
        end

        proposedRoi = currentRoi;
        proposedRoi(1:2) = proposedRoi(1:2)+delta;
        currentRoi = localClampRoi(proposedRoi,imageWidth,imageHeight);
        hitBoundary(frameIndex) = any(abs(currentRoi(1:2)-proposedRoi(1:2))>0.25);
        % 记录实际送入 imcrop 的整数 ROI；总位移合成必须使用真实裁剪位移，
        % 否则会把 ROI 浮点预测的小数部分与 M-PME 残差重复计算。
        roiTrajectory(frameIndex,:) = round(currentRoi);
        stepDisplacement(frameIndex,:) = delta;
        currentCrop = imcrop(gray,roiTrajectory(frameIndex,:));
        frames(:,:,frameIndex) = single(currentCrop);

        validPointCount(frameIndex) = size(newValid,1);
        if isempty(scoreValid)
            trackingQuality(frameIndex) = 0;
        else
            trackingQuality(frameIndex) = median(scoreValid,'omitnan');
        end

        needsRedetection = size(newValid,1)<options.redetectPointCount || ...
            mod(frameIndex,options.redetectInterval)==0 || ~reliable;
        if needsRedetection
            [refreshedPoints,~] = localDetectPoints(gray,currentRoi,options);
            release(tracker);
            if size(refreshedPoints,1)>=options.minimumPoints
                initialize(tracker,refreshedPoints,gray);
                previousPoints = refreshedPoints;
            elseif size(newValid,1)>=options.minimumPoints
                initialize(tracker,newValid,gray);
                previousPoints = newValid;
            else
                error(['第 %d 帧粗跟踪丢失：ROI 内特征不足。' ...
                    '请扩大初始 ROI、提高照明或增大 dynamicRoi.maximumStepPixels。'], ...
                    frameIndex);
            end
        else
            setPoints(tracker,newValid);
            previousPoints = newValid;
        end

        if writePreview
            previewTimer = tic;
            writeVideo(writer,localAnnotate(rgb,currentRoi,previousPoints, ...
                frameIndex,estimatedCount,validPointCount(frameIndex), ...
                trackingQuality(frameIndex),fallbackUsed(frameIndex)));
            previewWritingSeconds = previewWritingSeconds+toc(previewTimer);
        end
    end
    if writePreview, close(writer); end
catch caughtError
    if writePreview
        try
            close(writer);
        catch
            % 保留原始跟踪异常；关闭失败不覆盖根因。
        end
    end
    release(tracker);
    rethrow(caughtError);
end
release(tracker);

frames = frames(:,:,1:frameIndex);
roiTrajectory = roiTrajectory(1:frameIndex,:);
tracking = struct();
tracking.validPointCount = validPointCount(1:frameIndex);
tracking.quality = trackingQuality(1:frameIndex);
tracking.stepDisplacement = stepDisplacement(1:frameIndex,:);
tracking.fallbackUsed = fallbackUsed(1:frameIndex);
tracking.hitBoundary = hitBoundary(1:frameIndex);
tracking.coarseDisplacement = roiTrajectory(:,1:2)-roiTrajectory(1,1:2);
tracking.fallbackFrameCount = nnz(tracking.fallbackUsed);
tracking.boundaryFrameCount = nnz(tracking.hitBoundary);
tracking.previewWritingSeconds = previewWritingSeconds;
end

function options = localDefaults(options)
defaults = struct('maximumPoints',180,'minimumPoints',8,'redetectPointCount',25, ...
    'redetectInterval',20,'minimumQuality',0.01,'maximumBidirectionalError',2, ...
    'pyramidLevels',4,'outlierFloorPixels',1.5,'maximumStepPixels',80, ...
    'fallbackVelocityDecay',0.75,'previewFps',30);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(options,names{index}) || isempty(options.(names{index}))
        options.(names{index}) = defaults.(names{index});
    end
end
end

function gray = localGray(rgb)
if size(rgb,3)==3, gray = rgb2gray(rgb); else, gray = rgb; end
end

function roi = localClampRoi(roi,imageWidth,imageHeight)
roi(3) = min(max(round(roi(3)),2),imageWidth-1);
roi(4) = min(max(round(roi(4)),2),imageHeight-1);
roi(1) = min(max(roi(1),1),imageWidth-roi(3));
roi(2) = min(max(roi(2),1),imageHeight-roi(4));
end

function [points,strength] = localDetectPoints(gray,roi,options)
featurePoints = detectMinEigenFeatures(gray,'ROI',round(roi), ...
    'MinQuality',options.minimumQuality);
featurePoints = featurePoints.selectStrongest(options.maximumPoints);
points = featurePoints.Location;
strength = featurePoints.Metric;
end

function [delta,inlierMask,reliable] = localRobustTranslation(oldPoints,newPoints,options)
delta = [0 0];
inlierMask = false(size(oldPoints,1),1);
reliable = size(oldPoints,1)>=options.minimumPoints;
if ~reliable, return; end
pointSteps = newPoints-oldPoints;
medianStep = median(pointSteps,1);
deviation = hypot(pointSteps(:,1)-medianStep(1),pointSteps(:,2)-medianStep(2));
robustScale = 1.4826*median(abs(deviation-median(deviation)));
threshold = max(options.outlierFloorPixels,3*robustScale);
inlierMask = deviation<=threshold;
reliable = nnz(inlierMask)>=options.minimumPoints;
if reliable, delta = median(pointSteps(inlierMask,:),1); end
end

function rgb = localAnnotate(frame,roi,points,frameIndex,frameCount,pointCount,quality,fallback)
if size(frame,3)==1, rgb = repmat(frame,1,1,3); else, rgb = frame; end
rgb = insertShape(rgb,'Rectangle',round(roi),'Color',[230 85 13],'LineWidth',3);
if ~isempty(points)
    rgb = insertMarker(rgb,points,'+','Color',[0 158 115],'Size',3);
end
status = 'KLT';
if fallback, status = '预测保持'; end
label = sprintf('动态 ROI | %d/%d | 点=%d | 质量=%.3f | %s', ...
    frameIndex,frameCount,pointCount,quality,status);
rgb = insertText(rgb,[8 8],label,'FontSize',14,'TextColor','white', ...
    'BoxColor','black','BoxOpacity',0.65);
end
