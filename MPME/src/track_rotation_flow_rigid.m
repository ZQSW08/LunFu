function [transforms,stepAngles,tracking] = track_rotation_flow_rigid(frames,centre,options)
%TRACK_ROTATION_FLOW_RIGID 从转子运动区域的稠密切向光流估计粗转角。
% 先用全序列的时间标准差自动排除静态背景，再把 Farneback 光流投影到
% 绕轮毂的切向分量。输出只承担大转角初值，不对最终 M-PME 结果做低通。

if nargin<3, options = struct(); end
options = localDefaults(options,size(frames));
frameCount = size(frames,3);
[xGrid,yGrid] = meshgrid(0:size(frames,2)-1,0:size(frames,1)-1);
xFromCenter = xGrid-centre(1);
yFromCenter = yGrid-centre(2);
radiusSquared = xFromCenter.^2+yFromCenter.^2;
annulus = radiusSquared>=options.innerRadiusPixels^2 & ...
    radiusSquared<=options.outerRadiusPixels^2;

sampleIndices = unique(round(linspace(1,frameCount, ...
    min(frameCount,options.motionMaskFrameSamples))));
temporalDeviation = std(frames(:,:,sampleIndices),0,3);
maskValues = temporalDeviation(annulus);
maskCutoff = localPercentile(maskValues,options.motionMaskPercentile);
motionMask = annulus & temporalDeviation>=maskCutoff;

flowEstimator = opticalFlowFarneback('NumPyramidLevels',options.pyramidLevels, ...
    'PyramidScale',0.5,'NumIterations',options.iterations, ...
    'NeighborhoodSize',options.neighborhoodSize,'FilterSize',options.filterSize);
estimateFlow(flowEstimator,frames(:,:,1));
stepAngles = zeros(frameCount,1);
fitPixelCount = zeros(frameCount,1);
fallbackUsed = false(frameCount,1);
lastReliableStep = 0;

for frameIndex = 2:frameCount
    flow = estimateFlow(flowEstimator,frames(:,:,frameIndex));
    magnitude = hypot(flow.Vx,flow.Vy);
    safeRadius = sqrt(max(radiusSquared,1));
    angularRate = (-yFromCenter.*flow.Vx+xFromCenter.*flow.Vy) ./ ...
        max(radiusSquared,1);
    radialFlow = (xFromCenter.*flow.Vx+yFromCenter.*flow.Vy)./safeRadius;
    candidate = motionMask & magnitude>=options.minimumFlowPixels & ...
        abs(radialFlow)<=max(options.radialFlowFloorPixels, ...
        options.maximumRadialToTotalRatio*magnitude) & isfinite(angularRate);
    values = angularRate(candidate);
    if numel(values)>=options.minimumFitPixels
        initial = median(values);
        deviation = abs(values-initial);
        robustScale = 1.4826*median(abs(deviation-median(deviation)));
        threshold = max(deg2rad(options.outlierFloorDegrees),3*robustScale);
        values = values(deviation<=threshold);
    end
    reliable = numel(values)>=options.minimumFitPixels;
    if reliable
        stepAngle = rad2deg(median(values));
        if abs(stepAngle)>options.maximumStepDegrees
            reliable = false;
        end
    end
    if reliable
        lastReliableStep = stepAngle;
        fitPixelCount(frameIndex) = numel(values);
    else
        stepAngle = options.fallbackVelocityDecay*lastReliableStep;
        if abs(stepAngle)<options.minimumFallbackDegrees, stepAngle = 0; end
        fallbackUsed(frameIndex) = true;
    end
    stepAngles(frameIndex) = stepAngle;
end

cumulativeAngles = cumsum(stepAngles);
transforms = repmat(eye(3),1,1,frameCount);
for frameIndex = 2:frameCount
    transforms(:,:,frameIndex) = localRigidTransform(cumulativeAngles(frameIndex),centre);
end
tracking = struct('validPointCount',fitPixelCount, ...
    'movingPointCount',fitPixelCount,'fallbackUsed',fallbackUsed, ...
    'fallbackFrameCount',nnz(fallbackUsed),'motionMask',motionMask, ...
    'motionMaskCutoff',maskCutoff,'method','dense-flow');
end

function options = localDefaults(options,frameSize)
defaults = struct('innerRadiusPixels',8, ...
    'outerRadiusPixels',hypot(frameSize(2),frameSize(1)), ...
    'motionMaskFrameSamples',60,'motionMaskPercentile',65, ...
    'pyramidLevels',4,'iterations',5,'neighborhoodSize',9,'filterSize',15, ...
    'minimumFlowPixels',0.03,'radialFlowFloorPixels',1, ...
    'maximumRadialToTotalRatio',0.8,'minimumFitPixels',100, ...
    'outlierFloorDegrees',0.15,'maximumStepDegrees',20, ...
    'fallbackVelocityDecay',0.5,'minimumFallbackDegrees',0.02);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(options,names{index}) || isempty(options.(names{index}))
        options.(names{index}) = defaults.(names{index});
    end
end
end

function value = localPercentile(values,percentile)
values = sort(double(values(isfinite(values))));
if isempty(values), value = 0; return; end
position = 1+(numel(values)-1)*percentile/100;
lowerIndex = floor(position); upperIndex = ceil(position);
if lowerIndex==upperIndex
    value = values(lowerIndex);
else
    fraction = position-lowerIndex;
    value = values(lowerIndex)*(1-fraction)+values(upperIndex)*fraction;
end
end

function transform = localRigidTransform(angleDeg,centre)
angleRad = deg2rad(angleDeg);
rotation = [cos(angleRad) -sin(angleRad); sin(angleRad) cos(angleRad)];
centreColumn = centre(:);
translation = centreColumn-rotation*centreColumn;
transform = [rotation translation; 0 0 1];
end
