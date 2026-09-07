function [patch, valid] = extract_patch(I, center, halfSize, method)
%EXTRACT_PATCH 以 [x,y] 为中心进行亚像素子区采样。
if nargin < 4 || isempty(method)
    method = 'cubic';
end
[X, Y] = meshgrid(-halfSize:halfSize, -halfSize:halfSize);
xx = center(1) + X;
yy = center(2) + Y;
valid = xx >= 1 & xx <= size(I, 2) & yy >= 1 & yy <= size(I, 1);
patch = interp2(double(I), xx, yy, method, NaN);
end
