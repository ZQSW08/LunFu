function [roi, ok, message] = apcv_validate_roi(roi, imageSize, minSize)
%APCV_VALIDATE_ROI 将 [x y width height] 限制在图像边界并检查尺寸。

if nargin < 3 || isempty(minSize)
    minSize = [32 32];
end
ok = false;
message = '';
if isempty(roi) || numel(roi) ~= 4 || any(~isfinite(roi))
    message = 'ROI 必须是有限的 [x y width height]。';
    return;
end
roi = double(roi(:).');
roi(1) = max(1, floor(roi(1)));
roi(2) = max(1, floor(roi(2)));
roi(3) = floor(roi(3));
roi(4) = floor(roi(4));
roi(3) = min(roi(3), imageSize(2) - roi(1) + 1);
roi(4) = min(roi(4), imageSize(1) - roi(2) + 1);
if roi(3) < minSize(2) || roi(4) < minSize(1)
    message = sprintf('ROI 太小：至少需要 %d x %d 像素。', minSize(2), minSize(1));
    return;
end
ok = true;
end
