function [anglesDegrees,quality,diagnostics] = ...
    track_rotation_angular_harmonic(frames,centre,bladeCount,options)
%TRACK_ROTATION_ANGULAR_HARMONIC 用叶片数阶角向谐波测量高速转子角度。
% 将环形转子采样到极坐标，提取 exp(-i*N*theta) 复系数；其相位除以叶片数 N
% 即为轴角（模 360/N）。时间相位展开不依赖单个叶片特征点，适合重复纹理转子。

if nargin<4, options = struct(); end
if ~isfield(options,'angularSamples'), options.angularSamples = 720; end
if ~isfield(options,'radialSamples'), options.radialSamples = 96; end
if ~isfield(options,'innerRadiusPixels'), options.innerRadiusPixels = 8; end
if ~isfield(options,'outerRadiusPixels') || isempty(options.outerRadiusPixels)
    options.outerRadiusPixels = min([centre(1),centre(2), ...
        size(frames,2)-1-centre(1),size(frames,1)-1-centre(2)]);
end
if ~isfield(options,'maximumStepDegrees'), ...
        options.maximumStepDegrees = 0.45*360/bladeCount; end
if ~isfield(options,'enforceUnidirectional'), options.enforceUnidirectional = true; end
if ~isfield(options,'reverseToleranceDegrees'), options.reverseToleranceDegrees = 1; end
bladeCount = max(1,round(bladeCount));
frameCount = size(frames,3);
angles = (0:options.angularSamples-1).'*2*pi/options.angularSamples;
radii = linspace(options.innerRadiusPixels,options.outerRadiusPixels, ...
    options.radialSamples);
[radiusGrid,angleGrid] = meshgrid(radii,angles);
xQuery = centre(1)+radiusGrid.*cos(angleGrid);
yQuery = centre(2)+radiusGrid.*sin(angleGrid);
harmonicCarrier = exp(-1i*bladeCount*angles);
coefficient = zeros(frameCount,1);

for frameIndex = 1:frameCount
    image = double(frames(:,:,frameIndex));
    polarImage = interp2(0:size(image,2)-1,0:size(image,1)-1,image, ...
        xQuery,yQuery,'linear',NaN);
    valid = isfinite(polarImage);
    polarImage(~valid) = 0;
    validCount = sum(valid,1);
    radialMean = sum(polarImage,1)./max(validCount,1);
    polarImage = (polarImage-radialMean).*valid;
    radialScale = sqrt(sum(polarImage.^2,1))./sqrt(max(validCount,1));
    polarImage = polarImage./max(radialScale,eps);
    radialCoefficient = sum(polarImage.*harmonicCarrier,1)./max(validCount,1);
    coefficient(frameIndex) = sum(radialCoefficient,'omitnan');
end

% 静态背景在复系数中表现为近似常量；去掉时间中值后保留旋转分量。
backgroundCoefficient = median(real(coefficient))+1i*median(imag(coefficient));
dynamicCoefficient = coefficient-backgroundCoefficient;
quality = abs(dynamicCoefficient)/max(median(abs(dynamicCoefficient)),eps);
wrappedPhase = angle(dynamicCoefficient);
unwrappedPhase = unwrap(wrappedPhase);
anglesDegrees = -rad2deg(unwrappedPhase-unwrappedPhase(1))/bladeCount;
stepAngles = [0;diff(anglesDegrees)];
bad = abs(stepAngles)>options.maximumStepDegrees | quality<0.15;
if options.enforceUnidirectional
    substantial = stepAngles(abs(stepAngles)>=options.reverseToleranceDegrees & ~bad);
    dominantDirection = sign(median(substantial,'omitnan'));
    if ~isfinite(dominantDirection) || dominantDirection==0, dominantDirection = 1; end
    bad = bad | dominantDirection*stepAngles < -options.reverseToleranceDegrees;
else
    dominantDirection = NaN;
end
localBaseline = smoothdata(stepAngles,'movmedian',11,'omitnan');
deviation = abs(stepAngles-localBaseline);
robustScale = 1.4826*median(abs(deviation-median(deviation,'omitnan')),'omitnan');
bad = bad | deviation>max(8,4*robustScale);
stepAngles(bad) = NaN;
stepAngles = fillmissing(stepAngles,'linear','EndValues','nearest');
anglesDegrees = cumsum(stepAngles);
anglesDegrees = anglesDegrees-anglesDegrees(1);

diagnostics = struct('complexCoefficient',coefficient, ...
    'dynamicCoefficient',dynamicCoefficient,'stepAnglesDegrees',stepAngles, ...
    'rejectedFrames',bad,'rejectedFrameCount',nnz(bad), ...
    'bladeCount',bladeCount,'dominantDirection',dominantDirection, ...
    'maximumUnambiguousStepDegrees',180/bladeCount);
end
