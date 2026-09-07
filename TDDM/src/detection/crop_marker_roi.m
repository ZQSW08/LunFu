function [roi, origin, localCenter] = crop_marker_roi(I, center, sideLength)
%CROP_MARKER_ROI 从全图裁出局部检测区，并返回全图坐标原点。
sideLength = max(3, round(sideLength));
half = floor(sideLength / 2);
x0 = max(1, floor(center(1) - half));
y0 = max(1, floor(center(2) - half));
x1 = min(size(I, 2), x0 + sideLength - 1);
y1 = min(size(I, 1), y0 + sideLength - 1);
roi = I(y0:y1, x0:x1, :);
origin = [x0, y0];
localCenter = center - origin + 1;
end
