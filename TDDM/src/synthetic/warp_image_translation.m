function J = warp_image_translation(I, dx, dy, method)
%WARP_IMAGE_TRANSLATION 生成 current(x,y)=reference(x-dx,y-dy) 的真值平移图。
if nargin < 4, method = 'cubic'; end
[X, Y] = meshgrid(1:size(I,2), 1:size(I,1));
J = interp2(double(I), X-dx, Y-dy, method, NaN);
bad = isnan(J);
if any(bad(:))
    J(bad) = interp2(double(I), X(bad)-dx, Y(bad)-dy, 'nearest', 0);
end
J = min(max(J, 0), 1);
end
