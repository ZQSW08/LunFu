function [angleDeg, quality, correlation] = estimate_rotation_phase_anchor( ...
    reference, moving, centre, options)
%ESTIMATE_ROTATION_PHASE_ANCHOR 用极坐标相位相关估计相对首帧的绝对转角。
% 该粗转角只负责阻止相邻帧 M-PME 的误差累计；亚像素残差仍由 M-PME 提供。

if nargin < 4, options = struct; end
if ~isfield(options,'angularSamples'), options.angularSamples = 720; end
if ~isfield(options,'radialSamples'), options.radialSamples = 64; end
if ~isfield(options,'radiusFraction'), options.radiusFraction = [0.12 0.46]; end

referencePolar = localPolarImage(reference, centre, options);
movingPolar = localPolarImage(moving, centre, options);

% 每个半径独立去均值和归一化，避免静态背景和亮度变化主导相关峰。
referencePolar = referencePolar - mean(referencePolar,1);
movingPolar = movingPolar - mean(movingPolar,1);
referencePolar = referencePolar ./ max(sqrt(sum(referencePolar.^2,1)), eps);
movingPolar = movingPolar ./ max(sqrt(sum(movingPolar.^2,1)), eps);

referenceFft = fft(referencePolar, [], 1);
movingFft = fft(movingPolar, [], 1);
crossPowerByRadius = movingFft .* conj(referenceFft);
crossPowerByRadius = crossPowerByRadius ./ max(abs(crossPowerByRadius), eps);
crossPower = sum(crossPowerByRadius, 2);
correlation = real(ifft(crossPower));

[peakValue, peakIndex] = max(correlation);
sampleCount = options.angularSamples;
leftIndex = 1 + mod(peakIndex-2, sampleCount);
rightIndex = 1 + mod(peakIndex, sampleCount);
denominator = correlation(leftIndex) - 2*peakValue + correlation(rightIndex);
subsample = 0;
if abs(denominator) > eps
    subsample = 0.5 * (correlation(leftIndex)-correlation(rightIndex)) / denominator;
end
shiftSamples = (peakIndex-1) + subsample;
if shiftSamples >= sampleCount/2, shiftSamples = shiftSamples-sampleCount; end
angleDeg = 360 * shiftSamples / sampleCount;

% 峰值质量使用“主峰相对远离主峰区域的次峰”衡量，1 附近表示存在歧义。
excluded = false(sampleCount,1);
halfWidth = max(2, round(sampleCount/180));
excluded(1+mod((peakIndex-1-halfWidth):(peakIndex-1+halfWidth),sampleCount)) = true;
secondPeak = max(correlation(~excluded));
quality = (peakValue-min(correlation)) / max(secondPeak-min(correlation), eps);
end

function polarImage = localPolarImage(image, centre, options)
height = size(image,1); width = size(image,2);
maximumRadius = min([centre(1), centre(2), width-1-centre(1), height-1-centre(2)]);
radii = linspace(options.radiusFraction(1)*maximumRadius, ...
    options.radiusFraction(2)*maximumRadius, options.radialSamples);
angles = (0:options.angularSamples-1).' * 2*pi/options.angularSamples;
[radiusGrid, angleGrid] = meshgrid(radii, angles);
xQuery = centre(1) + radiusGrid.*cos(angleGrid);
yQuery = centre(2) + radiusGrid.*sin(angleGrid);
polarImage = interp2(0:width-1, 0:height-1, double(image), ...
    xQuery, yQuery, 'linear', median(image(:)));
end
