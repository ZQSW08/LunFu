function points = init_klt_points(I, markerROI, cfg)
%INIT_KLT_POINTS 在标记附近寻找 Shi-Tomasi/KLT 角点。
if size(I, 3) == 3
    I = rgb2gray(I);
end
[roi, origin] = crop_marker_roi(I, [(markerROI(1) + markerROI(3)/2), ...
    (markerROI(2) + markerROI(4)/2)], max(markerROI(3), markerROI(4)));
corners = detectMinEigenFeatures(roi, 'MinQuality', cfg.impl.kltQualityLevel, ...
    'FilterSize', max(3, cfg.impl.kltBlockSize));
if corners.Count == 0
    points = zeros(0, 2);
    return;
end
if corners.Count > cfg.impl.kltMaxCorners
    corners = corners.selectStrongest(cfg.impl.kltMaxCorners);
end
points = corners.Location + origin - 1;
end
