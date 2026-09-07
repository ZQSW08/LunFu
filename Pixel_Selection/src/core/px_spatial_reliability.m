function spatial = px_spatial_reliability(video, phaseDifference, amplitude, foreground, cfg)
% 计算MEI、SAM、PSE及Bayesian平均池化后的可靠像素集。
[height, width, frames] = size(video);
valid = logical(foreground.mask);
neighborhood = cfg.spatial.neighborhood;
kernel = ones(neighborhood, neighborhood) / (neighborhood * neighborhood);

meiAccum = zeros(height, width);
for frameIndex = 2:frames
    difference = double(video(:, :, frameIndex)) - double(video(:, :, frameIndex - 1));
    localMeanAbs = conv2(abs(difference), kernel, 'same');
    localMeanSq = conv2(difference.^2, kernel, 'same');
    localVariance = max(localMeanSq - localMeanAbs.^2, 0);
    meiAccum = meiAccum + sqrt(localVariance);
end
mei = meiAccum / max(frames - 1, 1);
sam = mean(double(amplitude), 3);

% PSE使用去均值后的单边频谱。论文给出了谱熵形式，但未规定是否排除直流项。
centered = double(phaseDifference) - mean(double(phaseDifference), 3);
frequencyCount = floor(frames / 2) + 1;
fourier = fft(centered, [], 3);
fourier = abs(fourier(:, :, 1:frequencyCount));
probability = fourier ./ (sum(fourier, 3) + eps);
pse = -sum(probability .* log(probability + eps), 3);

confidenceMei = px_confidence(mei, valid, true);
confidenceSam = px_confidence(sam, valid, true);
confidencePse = px_confidence(pse, valid, false);
fused = (confidenceMei + confidenceSam + confidencePse) / 3;
reliable = valid & fused > cfg.spatial.confidenceThreshold;
usedFallback = false;
if ~any(reliable(:)) && any(valid(:))
    indices = find(valid);
    count = max(1, floor(numel(indices) * cfg.spatial.fallbackFraction));
    [~, order] = sort(fused(indices), 'descend');
    reliable(indices(order(1:min(count, numel(order))))) = true;
    usedFallback = true;
end

spatial.mei = single(mei);
spatial.sam = single(sam);
spatial.pse = single(pse);
spatial.confidenceMei = single(confidenceMei);
spatial.confidenceSam = single(confidenceSam);
spatial.confidencePse = single(confidencePse);
spatial.confidenceFused = single(fused);
spatial.reliable = reliable;
spatial.usedFallback = usedFallback;
spatial.pixelCount = nnz(reliable);
end

function confidence = px_confidence(feature, valid, higherIsReliable)
% 使用前景内上下半组的经验高斯似然比构造置信度。
values = double(feature(valid));
confidence = zeros(size(feature));
if numel(values) < 8
    confidence(valid) = 0.5;
    return;
end
medianValue = median(values);
low = values(values <= medianValue);
high = values(values >= medianValue);
mu0 = mean(low);
sd0 = std(low) + 1e-8;
mu1 = mean(high);
sd1 = std(high) + 1e-8;
if ~higherIsReliable
    temp = mu0; mu0 = mu1; mu1 = temp;
    temp = sd0; sd0 = sd1; sd1 = temp;
end
x = double(feature);
logP1 = -0.5 * ((x - mu1) ./ sd1).^2 - log(sd1);
logP0 = -0.5 * ((x - mu0) ./ sd0).^2 - log(sd0);
logRatio = min(max(logP1 - logP0, -60), 60);
confidence(valid) = 1 ./ (1 + exp(-logRatio(valid)));
end
