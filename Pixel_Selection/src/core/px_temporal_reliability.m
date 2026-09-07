function temporal = px_temporal_reliability(phaseDifference, reliable, cfg)
% 聚合可靠像素，按窗口稳健检测异常时间片段。
if ~any(reliable(:))
    error('可靠像素集为空，无法进行时间可靠性分析。');
end
[~, ~, frames] = size(phaseDifference);
pixelMatrix = reshape(double(phaseDifference), [], frames);
signal = mean(pixelMatrix(reliable(:), :), 1)';
difference = diff(signal);
windowFrames = cfg.temporal.windowFrames;
windowCount = ceil(numel(difference) / windowFrames);
windowStd = zeros(windowCount, 1);
windowRange = zeros(windowCount, 1);
for windowIndex = 1:windowCount
    first = (windowIndex - 1) * windowFrames + 1;
    last = min(windowIndex * windowFrames, numel(difference));
    section = difference(first:last);
    windowStd(windowIndex) = std(section);
    windowRange(windowIndex) = max(section) - min(section);
end
zStd = px_robust_z(windowStd);
zRange = px_robust_z(windowRange);
scores = max(abs([zStd, zRange]), [], 2);
tau = px_percentile(abs([zStd; zRange]), cfg.temporal.percentile);
badWindows = scores > tau;
observed = true(size(difference));
for windowIndex = 1:windowCount
    if badWindows(windowIndex)
        first = (windowIndex - 1) * windowFrames + 1;
        last = min(windowIndex * windowFrames, numel(difference));
        observed(first:last) = false;
    end
end
if nnz(observed) < max(8, floor(numel(difference) / 20))
    observed(:) = false;
    [~, order] = sort(scores, 'ascend');
    keepCount = max(1, floor(windowCount / 2));
    for index = 1:keepCount
        windowIndex = order(index);
        first = (windowIndex - 1) * windowFrames + 1;
        last = min(windowIndex * windowFrames, numel(difference));
        observed(first:last) = true;
    end
end
refined = difference;
refined(~observed) = 0;

temporal.signal = signal;
temporal.difference = difference;
temporal.refined = refined;
temporal.observed = observed;
temporal.windowStd = windowStd;
temporal.windowRange = windowRange;
temporal.zStd = zStd;
temporal.zRange = zRange;
temporal.tau = tau;
temporal.badWindows = badWindows;
end

function z = px_robust_z(values)
% 用中位数和MAD计算稳健Z分数。
center = median(values);
scale = 1.4826 * median(abs(values - center));
if scale < 1e-10
    scale = std(values) + 1e-10;
end
z = (values - center) / scale;
end
