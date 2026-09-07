function [mask, rho, threshold] = apcv_select_active_pixels(phaseDifference)
%APCV_SELECT_ACTIVE_PIXELS 实现论文式 (18)-(21) 的相关主动像素选择。
% phaseDifference 的维度为 [height, width, frames]。

[h, w, n] = size(phaseDifference);
samples = reshape(double(phaseDifference), h*w, n);
globalReference = mean(samples, 1, 'omitnan');
globalCentered = globalReference - mean(globalReference, 'omitnan');
sampleCentered = samples - mean(samples, 2, 'omitnan');
denominator = sqrt(sum(sampleCentered.^2, 2)) * norm(globalCentered);
rhoVector = (sampleCentered * globalCentered') ./ max(denominator, eps);
rhoVector(~isfinite(rhoVector)) = -1;
rho = reshape(max(min(rhoVector, 1), -1), h, w);

normalized = (rho + 1) / 2;
thresholdNormalized = graythresh(normalized);
threshold = 2 * thresholdNormalized - 1;
mask = rho >= threshold;

% Otsu 在近常量图上可能给出空集合；此时保留相关性最高的 20%。
if nnz(mask) < max(12, round(0.02*numel(mask)))
    sorted = sort(rhoVector, 'descend');
    threshold = sorted(max(1, round(0.20*numel(sorted))));
    mask = rho >= threshold;
end
end
