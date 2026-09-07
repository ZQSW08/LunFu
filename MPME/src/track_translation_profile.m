function [displacement,quality] = track_translation_profile(frames,axisName,options)
%TRACK_TRANSLATION_PROFILE 用正交方向平均梯度的一维相关估计稳健平移。
% 该估计器适合细长边缘/条纹 ROI，作为 M-PME 的独立质量校验和失效回退；
% 它不经过时间带通，因此不会预先假定振动频率。

if nargin<2 || isempty(axisName), axisName = 'x'; end
if nargin<3, options = struct(); end
if ~isfield(options,'maximumShiftPixels'), options.maximumShiftPixels = []; end
if ~isfield(options,'smoothingSigma'), options.smoothingSigma = 0.8; end
if ~isfield(options,'referenceMode'), options.referenceMode = 'fixed'; end
frameCount = size(frames,3);
referenceProfile = localProfile(frames(:,:,1),axisName,options);
profileLength = numel(referenceProfile);
if isempty(options.maximumShiftPixels)
    maximumShift = max(2,floor(profileLength/3));
else
    maximumShift = min(floor(profileLength/2),round(options.maximumShiftPixels));
end
lags = (-maximumShift:maximumShift).';
displacement = zeros(frameCount,1);
quality = ones(frameCount,1);

for frameIndex = 2:frameCount
    movingProfile = localProfile(frames(:,:,frameIndex),axisName,options);
    correlation = zeros(numel(lags),1);
    for lagIndex = 1:numel(lags)
        lag = lags(lagIndex);
        if lag>=0
            referencePart = referenceProfile(1:end-lag);
            movingPart = movingProfile(1+lag:end);
        else
            shift = -lag;
            referencePart = referenceProfile(1+shift:end);
            movingPart = movingProfile(1:end-shift);
        end
        referencePart = referencePart-mean(referencePart);
        movingPart = movingPart-mean(movingPart);
        denominator = norm(referencePart)*norm(movingPart);
        if denominator>eps
            correlation(lagIndex) = dot(referencePart,movingPart)/denominator;
        end
    end
    [peakValue,peakIndex] = max(correlation);
    subsample = 0;
    if peakIndex>1 && peakIndex<numel(correlation)
        left = correlation(peakIndex-1); right = correlation(peakIndex+1);
        denominator = left-2*peakValue+right;
        if abs(denominator)>eps
            subsample = 0.5*(left-right)/denominator;
            subsample = min(max(subsample,-0.5),0.5);
        end
    end
    currentShift = lags(peakIndex)+subsample;
    if strcmpi(options.referenceMode,'adjacent')
        displacement(frameIndex) = displacement(frameIndex-1)+currentShift;
        referenceProfile = movingProfile;
    else
        displacement(frameIndex) = currentShift;
    end
    excluded = abs(lags-lags(peakIndex))<=2;
    secondPeak = max(correlation(~excluded),[],'omitnan');
    quality(frameIndex) = (peakValue+1)/max(secondPeak+1,eps);
end
end

function profile = localProfile(frame,axisName,options)
image = double(frame);
if options.smoothingSigma>0
    image = imgaussfilt(image,options.smoothingSigma,'Padding','symmetric');
end
if strcmpi(axisName,'y')
    gradientImage = abs(imfilter(image,[-1;0;1]/2,'replicate','same'));
    profile = mean(gradientImage,2);
else
    gradientImage = abs(imfilter(image,[-1 0 1]/2,'replicate','same'));
    profile = mean(gradientImage,1).';
end
profile = profile-median(profile);
scale = median(abs(profile))+eps;
profile = profile/scale;
end
