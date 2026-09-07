function [transforms,stepAngles,tracking] = track_rotation_klt_rigid(frames,centre,options)
%TRACK_ROTATION_KLT_RIGID 以已知轮毂为中心，从 KLT 点直接估计刚体粗转角。
% 静态背景点因切向位移接近零被排除；旋转叶片点必须同时满足径向漂移小、
% 帧间位移充分和角度一致。该结果适合承担大转角，M-PME 再测残余小转角。

if nargin<3, options = struct(); end
options = localDefaults(options,size(frames));
frameCount = size(frames,3);
transforms = repmat(eye(3),1,1,frameCount);
stepAngles = zeros(frameCount,1);
validPointCount = zeros(frameCount,1);
movingPointCount = zeros(frameCount,1);
fallbackUsed = false(frameCount,1);

firstFrame = frames(:,:,1);
points = localDetect(firstFrame,centre,options);
if size(points,1)<options.minimumTrackPoints
    error('轮毂周围仅检测到 %d 个特征点，至少需要 %d 个。', ...
        size(points,1),options.minimumTrackPoints);
end
tracker = vision.PointTracker('MaxBidirectionalError', ...
    options.maximumBidirectionalError,'NumPyramidLevels',options.pyramidLevels);
initialize(tracker,points,firstFrame);
previousPoints = points;
validPointCount(1) = size(points,1);
lastReliableStep = 0;
cumulativeAngle = 0;

try
    for frameIndex = 2:frameCount
        currentFrame = frames(:,:,frameIndex);
        [newPoints,validity,scores] = tracker(currentFrame);
        valid = validity & all(isfinite(newPoints),2) & all(isfinite(previousPoints),2);
        oldValid = previousPoints(valid,:);
        newValid = newPoints(valid,:);
        scoreValid = scores(valid);
        [stepAngle,inliers,reliable] = localRigidAngle( ...
            oldValid,newValid,scoreValid,centre,options);
        if reliable
            newValid = newValid(inliers,:);
            lastReliableStep = stepAngle;
        else
            stepAngle = options.fallbackVelocityDecay*lastReliableStep;
            if abs(stepAngle)<options.minimumFallbackDegrees, stepAngle = 0; end
            fallbackUsed(frameIndex) = true;
        end
        stepAngles(frameIndex) = stepAngle;
        validPointCount(frameIndex) = nnz(valid);
        movingPointCount(frameIndex) = size(newValid,1);
        cumulativeAngle = cumulativeAngle+stepAngle;
        transforms(:,:,frameIndex) = localRigidTransform(cumulativeAngle,centre);

        needsRedetection = mod(frameIndex,options.redetectInterval)==0 || ...
            size(newValid,1)<options.redetectPointCount;
        if needsRedetection
            refreshed = localDetect(currentFrame,centre,options);
            release(tracker);
            if size(refreshed,1)>=options.minimumTrackPoints
                initialize(tracker,refreshed,currentFrame);
                previousPoints = refreshed;
            elseif size(newValid,1)>=options.minimumTrackPoints
                initialize(tracker,newValid,currentFrame);
                previousPoints = newValid;
            else
                error('第 %d 帧轮毂周围特征不足，刚体转角粗跟踪中断。',frameIndex);
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

tracking = struct('validPointCount',validPointCount, ...
    'movingPointCount',movingPointCount,'fallbackUsed',fallbackUsed, ...
    'fallbackFrameCount',nnz(fallbackUsed));
end

function options = localDefaults(options,frameSize)
maximumPossibleRadius = hypot(frameSize(2),frameSize(1));
defaults = struct('maximumPoints',200,'minimumTrackPoints',8, ...
    'minimumMovingPoints',4,'redetectPointCount',12,'redetectInterval',10, ...
    'minimumQuality',0.001,'maximumBidirectionalError',2, ...
    'pyramidLevels',4,'minimumMotionPixels',0.2,'maximumRadialDriftPixels',4, ...
    'maximumStepDegrees',30,'outlierFloorDegrees',0.35, ...
    'fallbackVelocityDecay',0.5,'minimumFallbackDegrees',0.05, ...
    'innerRadiusPixels',8,'outerRadiusPixels',maximumPossibleRadius);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(options,names{index}) || isempty(options.(names{index}))
        options.(names{index}) = defaults.(names{index});
    end
end
end

function points = localDetect(frame,centre,options)
features = detectMinEigenFeatures(frame,'MinQuality',options.minimumQuality);
locations = features.Location;
metrics = features.Metric;
radii = hypot(locations(:,1)-centre(1),locations(:,2)-centre(2));
valid = radii>=options.innerRadiusPixels & radii<=options.outerRadiusPixels;
locations = locations(valid,:); metrics = metrics(valid);
[~,order] = sort(metrics,'descend');
order = order(1:min(options.maximumPoints,numel(order)));
points = locations(order,:);
end

function [angleDeg,inlierMask,reliable] = localRigidAngle( ...
    oldPoints,newPoints,scores,centre,options)
pointCount = size(oldPoints,1);
inlierMask = false(pointCount,1);
angleDeg = 0;
if pointCount<options.minimumTrackPoints, reliable = false; return; end
oldVector = oldPoints-centre;
newVector = newPoints-centre;
oldRadius = hypot(oldVector(:,1),oldVector(:,2));
newRadius = hypot(newVector(:,1),newVector(:,2));
motion = hypot(newPoints(:,1)-oldPoints(:,1),newPoints(:,2)-oldPoints(:,2));
crossValue = oldVector(:,1).*newVector(:,2)-oldVector(:,2).*newVector(:,1);
dotValue = sum(oldVector.*newVector,2);
angles = atan2d(crossValue,dotValue);
candidate = oldRadius>=options.innerRadiusPixels & ...
    oldRadius<=options.outerRadiusPixels & ...
    abs(newRadius-oldRadius)<=options.maximumRadialDriftPixels & ...
    motion>=options.minimumMotionPixels & ...
    abs(angles)<=options.maximumStepDegrees & isfinite(scores);
if nnz(candidate)<options.minimumMovingPoints, reliable = false; return; end
weights = max(motion(candidate),eps).*max(double(scores(candidate)),eps);
candidateAngles = angles(candidate);
initial = localWeightedMedian(candidateAngles,weights);
deviation = abs(candidateAngles-initial);
scale = 1.4826*median(abs(deviation-median(deviation)));
threshold = max(options.outlierFloorDegrees,3*scale);
candidateInlier = deviation<=threshold;
candidateIndex = find(candidate);
inlierMask(candidateIndex(candidateInlier)) = true;
reliable = nnz(inlierMask)>=options.minimumMovingPoints;
if reliable
    angleDeg = localWeightedMedian(angles(inlierMask), ...
        max(motion(inlierMask),eps).*max(double(scores(inlierMask)),eps));
end
end

function value = localWeightedMedian(values,weights)
[values,order] = sort(values(:));
weights = weights(order);
cumulative = cumsum(weights)/sum(weights);
value = values(find(cumulative>=0.5,1,'first'));
end

function transform = localRigidTransform(angleDeg,centre)
angleRad = deg2rad(angleDeg);
rotation = [cos(angleRad) -sin(angleRad); sin(angleRad) cos(angleRad)];
centreColumn = centre(:);
translation = centreColumn-rotation*centreColumn;
transform = [rotation translation; 0 0 1];
end
