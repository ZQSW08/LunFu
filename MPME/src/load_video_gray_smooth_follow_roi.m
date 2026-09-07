function [frames,fps,roiTrajectory,tracking] = load_video_gray_smooth_follow_roi( ...
    videoPath,maxFrames,initialRoi,options,previewPath)
%LOAD_VIDEO_GRAY_SMOOTH_FOLLOW_ROI 两遍式大运动补偿，不跟随微振动。
% 第一遍以 KLT 估计原始目标轨迹并鲁棒平滑，仅保留低频大运动；第二遍按
% 平滑轨迹重新裁剪视频，使高频微振动留在稳定 ROI 中供 M-PME 测量。

if nargin < 2 || isempty(maxFrames), maxFrames = Inf; end
if nargin < 4 || isempty(options), options = struct(); end
if nargin < 5, previewPath = ''; end
options = localDefaults(options);

%% 第一遍：只估计目标原始轨迹，不生成裁剪序列
reader = VideoReader(videoPath);
fps = reader.FrameRate;
estimatedCount = min(maxFrames,max(1,floor(reader.Duration*fps)));
firstRgb = readFrame(reader);
firstGray = localGray(firstRgb);
[imageHeight,imageWidth] = size(firstGray);
initialRoi = localClampRoi(double(initialRoi),imageWidth,imageHeight);
currentRoi = initialRoi;

rawRoiTrajectory = nan(estimatedCount,4);
rawRoiTrajectory(1,:) = currentRoi;
validPointCount = zeros(estimatedCount,1);
trackingQuality = nan(estimatedCount,1);
stepDisplacement = zeros(estimatedCount,2);
fallbackUsed = false(estimatedCount,1);
templateScore = nan(estimatedCount,1);
templateCorrectionUsed = false(estimatedCount,1);
redetectionUsed = false(estimatedCount,1);
templateImage = localTemplateFeature(imcrop(firstGray,currentRoi));

[points,pointStrength] = localDetectPoints(firstGray,currentRoi,options);
if size(points,1)<options.minimumPoints
    error(['所选 ROI 内只有 %d 个可跟踪特征点，至少需要 %d 个。' ...
        '请让 ROI 包含目标边缘、斑点或文字；无需覆盖目标的完整运动路径。'], ...
        size(points,1),options.minimumPoints);
end
tracker = vision.PointTracker('MaxBidirectionalError', ...
    options.maximumBidirectionalError,'NumPyramidLevels',options.pyramidLevels);
initialize(tracker,points,firstGray);
previousPoints = points;
validPointCount(1) = size(points,1);
trackingQuality(1) = mean(pointStrength,'omitnan');
frameIndex = 1;
lastReliableStep = [0 0];

try
    while hasFrame(reader) && frameIndex<estimatedCount
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
            delta = options.fallbackVelocityDecay*lastReliableStep;
            fallbackUsed(frameIndex) = true;
        end
        if norm(delta)>options.maximumStepPixels
            delta = delta/norm(delta)*options.maximumStepPixels;
            fallbackUsed(frameIndex) = true;
        end

        proposedRoi = currentRoi;
        proposedRoi(1:2) = proposedRoi(1:2)+delta;
        proposedRoi = localClampRoi(proposedRoi,imageWidth,imageHeight);
        if options.templateVerificationEnabled && ...
                mod(frameIndex-1,options.templateVerificationInterval)==0
            [verifiedRoi,score,accepted] = localVerifyTemplate( ...
                gray,templateImage,proposedRoi,imageWidth,imageHeight,options);
            templateScore(frameIndex) = score;
            if accepted
                delta = delta+(verifiedRoi(1:2)-proposedRoi(1:2));
                proposedRoi = verifiedRoi;
                templateCorrectionUsed(frameIndex) = true;
            end
        end
        currentRoi = proposedRoi;
        rawRoiTrajectory(frameIndex,:) = currentRoi;
        stepDisplacement(frameIndex,:) = delta;
        validPointCount(frameIndex) = size(newValid,1);
        if isempty(scoreValid)
            trackingQuality(frameIndex) = 0;
        else
            trackingQuality(frameIndex) = median(scoreValid,'omitnan');
        end

        needsRedetection = size(newValid,1)<options.redetectPointCount || ...
            mod(frameIndex,options.redetectInterval)==0 || ~reliable;
        redetectionUsed(frameIndex) = needsRedetection;
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
                error(['第 %d 帧粗跟踪丢失：目标 ROI 内特征不足。' ...
                    '可降低 minimumPoints、提高照明或选择更有纹理的小区域。'],frameIndex);
            end
        else
            setPoints(tracker,newValid);
            previousPoints = newValid;
        end
    end
catch caughtError
    release(tracker);
    rethrow(caughtError);
end
release(tracker);

rawRoiTrajectory = rawRoiTrajectory(1:frameIndex,:);
validPointCount = validPointCount(1:frameIndex);
trackingQuality = trackingQuality(1:frameIndex);
stepDisplacement = stepDisplacement(1:frameIndex,:);
fallbackUsed = fallbackUsed(1:frameIndex);
templateScore = templateScore(1:frameIndex);
templateCorrectionUsed = templateCorrectionUsed(1:frameIndex);
redetectionUsed = redetectionUsed(1:frameIndex);
rawDisplacement = rawRoiTrajectory(:,1:2)-rawRoiTrajectory(1,1:2);
[largeMotionContinuous,kltMicroCandidate,macroDiagnostics] = ...
    estimate_macro_motion(rawDisplacement,fps,options);

%% 第二遍：仅跟随低频大运动，微振动保留在裁剪图像中
roiTrajectory = repmat(initialRoi,frameIndex,1);
hitBoundary = false(frameIndex,1);
for index = 1:frameIndex
    proposed = initialRoi;
    proposed(1:2) = proposed(1:2)+largeMotionContinuous(index,:);
    clamped = localClampRoi(proposed,imageWidth,imageHeight);
    hitBoundary(index) = any(abs(clamped(1:2)-proposed(1:2))>0.25);
    roiTrajectory(index,:) = round(clamped);
end

secondReader = VideoReader(videoPath);
firstCrop = imcrop(firstGray,roiTrajectory(1,:));
frames = zeros(size(firstCrop,1),size(firstCrop,2),frameIndex,'single');
writePreview = ~isempty(previewPath);
previewWritingSeconds = 0;
if writePreview
    writer = VideoWriter(previewPath,'MPEG-4');
    writer.FrameRate = min(fps,options.previewFps);
    writer.Quality = 90;
    open(writer);
end
try
    for index = 1:frameIndex
        rgb = readFrame(secondReader);
        gray = localGray(rgb);
        frames(:,:,index) = single(imcrop(gray,roiTrajectory(index,:)));
        if writePreview
            previewTimer = tic;
            annotated = localAnnotate(rgb,roiTrajectory(index,:),index,frameIndex, ...
                validPointCount(index),trackingQuality(index),fallbackUsed(index), ...
                rawDisplacement(index,:),largeMotionContinuous(index,:));
            writeVideo(writer,annotated);
            previewWritingSeconds = previewWritingSeconds+toc(previewTimer);
        end
    end
    if writePreview, close(writer); end
catch caughtError
    if writePreview
        try
            close(writer);
        catch
            % 保留视频读取/写出根因。
        end
    end
    rethrow(caughtError);
end

tracking = struct();
tracking.trackerType = 'klt';
tracking.dynamicRoiMode = macroDiagnostics.mode;
tracking.validPointCount = validPointCount;
tracking.quality = trackingQuality;
tracking.stepDisplacement = stepDisplacement;
tracking.fallbackUsed = fallbackUsed;
tracking.templateScore = templateScore;
tracking.templateCorrectionUsed = templateCorrectionUsed;
tracking.redetectionUsed = redetectionUsed;
tracking.rawRoiTrajectory = rawRoiTrajectory;
tracking.bbox_xywh = rawRoiTrajectory;
tracking.center_xy = rawRoiTrajectory(:,1:2)+0.5*rawRoiTrajectory(:,3:4);
tracking.scale = rawRoiTrajectory(:,3:4)./initialRoi(3:4);
tracking.confidence = trackingQuality;
tracking.valid = ~fallbackUsed;
tracking.lost = fallbackUsed;
tracking.redetect = redetectionUsed;
tracking.hitBoundary = hitBoundary;
tracking.rawCoarseDisplacement = rawDisplacement;
tracking.largeMotionContinuous = largeMotionContinuous;
tracking.kltMicroCandidate = kltMicroCandidate;
tracking.coarseDisplacement = roiTrajectory(:,1:2)-roiTrajectory(1,1:2);
tracking.expectedCoarseDisplacement = largeMotionContinuous;
tracking.macroTrendDiagnostics = macroDiagnostics;
tracking.macro = struct('xy',largeMotionContinuous, ...
    'microCandidate',kltMicroCandidate);
tracking.crop = struct('origin_xy',roiTrajectory(:,1:2), ...
    'bbox_xywh',roiTrajectory,'valid',~hitBoundary, ...
    'expected_xy',initialRoi(1:2)+largeMotionContinuous);
tracking.fallbackFrameCount = nnz(fallbackUsed);
tracking.templateCorrectionFrameCount = nnz(templateCorrectionUsed);
tracking.boundaryFrameCount = nnz(hitBoundary);
tracking.previewWritingSeconds = previewWritingSeconds;
tracking.largeMotionCutoffHz = macroDiagnostics.cutoffHz;
tracking.trackingAxis = options.trackingAxis;
end

function options = localDefaults(options)
defaults = struct('maximumPoints',120,'minimumPoints',5,'redetectPointCount',15, ...
    'redetectInterval',30,'minimumQuality',0.005,'maximumBidirectionalError',2, ...
    'pyramidLevels',3,'outlierFloorPixels',1.5,'maximumStepPixels',80, ...
    'fallbackVelocityDecay',0.75,'previewFps',30,'largeMotionCutoffHz',1, ...
    'macroTrendCutoffHz',[],'macroTrendWindowSeconds',0.5,'mode','trend', ...
    'trajectoryOutlierWindowSeconds',0.15,'trackingAxis','xy', ...
    'templateVerificationEnabled',true,'templateVerificationInterval',5, ...
    'templateSearchMarginPixels',24,'templateMaximumCorrectionPixels',12, ...
    'templateMinimumScore',0.20);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(options,names{index}) || isempty(options.(names{index}))
        options.(names{index}) = defaults.(names{index});
    end
end
end

function [verifiedRoi,score,accepted] = localVerifyTemplate( ...
    gray,templateImage,proposedRoi,imageWidth,imageHeight,options)
margin = options.templateSearchMarginPixels;
searchRoi = [proposedRoi(1)-margin proposedRoi(2)-margin ...
    proposedRoi(3)+2*margin proposedRoi(4)+2*margin];
searchRoi = localClampRoi(searchRoi,imageWidth,imageHeight);
searchImage = localTemplateFeature(imcrop(gray,searchRoi));
verifiedRoi = proposedRoi;
score = NaN; accepted = false;
if any(size(searchImage)<size(templateImage)), return; end
correlation = normxcorr2(templateImage,searchImage);
validRows = size(templateImage,1):size(searchImage,1);
validColumns = size(templateImage,2):size(searchImage,2);
validCorrelation = correlation(validRows,validColumns);
[score,linearIndex] = max(validCorrelation,[],'all','linear');
[rowIndex,columnIndex] = ind2sub(size(validCorrelation),linearIndex);
candidate = proposedRoi;
candidate(1) = searchRoi(1)+columnIndex-1;
candidate(2) = searchRoi(2)+rowIndex-1;
candidate = localClampRoi(candidate,imageWidth,imageHeight);
correction = candidate(1:2)-proposedRoi(1:2);
if isfinite(score) && score>=options.templateMinimumScore && ...
        norm(correction)<=options.templateMaximumCorrectionPixels
    verifiedRoi = candidate;
    accepted = true;
end
end

function feature = localTemplateFeature(image)
image = imgaussfilt(double(image),0.8,'Padding','symmetric');
[gradientX,gradientY] = imgradientxy(image,'sobel');
feature = hypot(gradientX,gradientY);
feature = feature-mean(feature,'all');
feature = feature/max(std(feature,0,'all'),eps);
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

function rgb = localAnnotate(frame,roi,frameIndex,frameCount,pointCount,quality, ...
    fallback,rawDisplacement,largeMotion)
if size(frame,3)==1, rgb = repmat(frame,1,1,3); else, rgb = frame; end
rgb = insertShape(rgb,'Rectangle',round(roi),'Color',[230 85 13],'LineWidth',3);
status = 'KLT+低频轨迹';
if fallback, status = '短时预测+低频轨迹'; end
label = sprintf(['动态 ROI | %d/%d | 点=%d | Q=%.3f | %s\n' ...
    '原始轨迹=(%.2f,%.2f) | 大运动=(%.2f,%.2f)'], ...
    frameIndex,frameCount,pointCount,quality,status,rawDisplacement,largeMotion);
rgb = insertText(rgb,[8 8],label,'FontSize',13,'TextColor','white', ...
    'BoxColor','black','BoxOpacity',0.65);
end
