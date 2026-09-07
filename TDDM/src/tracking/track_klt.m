function result = track_klt(prevI, currI, points0, cfg)
%TRACK_KLT 用 Lucas-Kanade 金字塔和显式 forward-backward 检查跟踪角点。
result = struct('prevPoints', zeros(0,2), 'currPoints', zeros(0,2), ...
    'backPoints', zeros(0,2), 'fbError', zeros(0,1), 'valid', false(0,1), ...
    'success', false, 'failureReason', 'no_input_points');
if isempty(points0)
    return;
end
if size(prevI, 3) == 3, prevI = rgb2gray(prevI); end
if size(currI, 3) == 3, currI = rgb2gray(currI); end
try
    fbThreshold = cfg.impl.kltMaxBidirectionalError;
    if ~cfg.impl.useForwardBackward, fbThreshold = Inf; end
    tracker = vision.PointTracker('MaxBidirectionalError', ...
        fbThreshold, 'NumPyramidLevels', ...
        cfg.impl.kltNumPyramidLevels);
    initialize(tracker, points0, prevI);
    [points1, valid1] = tracker(currI);
    release(tracker);
    result.prevPoints = points0(valid1, :);
    result.currPoints = points1(valid1, :);
    if isempty(result.currPoints)
        result.failureReason = 'forward_tracking_failed';
        return;
    end
    trackerBack = vision.PointTracker('MaxBidirectionalError', Inf, ...
        'NumPyramidLevels', cfg.impl.kltNumPyramidLevels);
    initialize(trackerBack, result.currPoints, currI);
    [back, validBack] = trackerBack(prevI);
    release(trackerBack);
    result.backPoints = back;
    result.fbError = sqrt(sum((result.prevPoints - back).^2, 2));
    if cfg.impl.useForwardBackward
        result.valid = validBack & result.fbError <= cfg.impl.kltMaxBidirectionalError;
    else
        result.valid = true(size(validBack)) & validBack;
    end
    result.success = any(result.valid);
    if ~result.success
        result.failureReason = 'forward_backward_failed';
    else
        result.failureReason = '';
    end
catch ME
    result.failureReason = ['point_tracker_error: ' ME.identifier];
end
end
