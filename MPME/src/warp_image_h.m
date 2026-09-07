function [warped, valid] = warp_image_h(image, H, fillValue)
%WARP_IMAGE_H Inverse-sample IMAGE using a 0-based output-to-input map H.

if nargin < 3 || isempty(fillValue)
    fillValue = median(double(image(:)));
end
[height, width] = size(image);
[x, y] = meshgrid(0:width-1, 0:height-1);
mapped = H * [x(:).'; y(:).'; ones(1, numel(x))];
xin = reshape(mapped(1, :) ./ mapped(3, :), height, width);
yin = reshape(mapped(2, :) ./ mapped(3, :), height, width);
valid = xin >= 0 & xin <= width-1 & yin >= 0 & yin <= height-1;
warped = interp2(0:width-1, 0:height-1, double(image), xin, yin, ...
    'linear', double(fillValue));
end
