function est = estimate_klt_sequence(images, cfg)
%ESTIMATE_KLT_SEQUENCE 使用 MATLAB PointTracker 实现论文 Fig. 9 的 KLT 参考。
%   选择初始帧中最接近 ROI 中心的高质量角点，输出其相对于首帧的像素位移。

[H, W, N] = size(images);
first = uint8(255 * images(:, :, 1));
points = detectMinEigenFeatures(first, 'MinQuality', 0.001, 'FilterSize', 5);
if points.Count == 0
    est.cumulativeUV = zeros(2, N);
    est.deltaUV = zeros(2, N - 1);
    est.valid = false;
    return
end

locations = points.Location;
center = [(W + 1) / 2, (H + 1) / 2];
[~, selected] = min(sum((locations - center) .^ 2, 2));
tracker = vision.PointTracker('MaxBidirectionalError', 2, 'NumPyramidLevels', 3);
initialize(tracker, locations, first);
initialPoint = locations(selected, :);
track = nan(N, 2);
track(1, :) = initialPoint;
valid = true(N, 1);
for k = 2:N
    [tracked, ok] = step(tracker, uint8(255 * images(:, :, k)));
    if ok(selected)
        track(k, :) = tracked(selected, :);
    else
        valid(k) = false;
        track(k, :) = track(k - 1, :);
    end
end
release(tracker);

est.cumulativeUV = (track - initialPoint)';
est.deltaUV = diff(est.cumulativeUV, 1, 2);
est.valid = valid;
end
