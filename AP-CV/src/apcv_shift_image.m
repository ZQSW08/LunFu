function shifted = apcv_shift_image(image, displacementPixels, direction)
%APCV_SHIFT_IMAGE 对图像做无循环回绕的亚像素平移。
% displacementPixels > 0 表示沿指定方向正向移动：
%   vertical   为图像向下；horizontal 为图像向右。
% 未提供 direction 时保持历史默认行为（vertical），不影响合成实验。

if nargin < 3 || isempty(direction)
    direction = 'vertical';
end
direction = apcv_normalize_direction(direction);
if strcmpi(direction, 'horizontal')
    translation = [displacementPixels, 0];
elseif strcmpi(direction, 'vertical')
    translation = [0, displacementPixels];
else
    error('direction 必须为 vertical 或 horizontal。');
end

fillValue = median(image(:), 'omitnan');
shifted = imtranslate(image, translation, 'linear', ...
    'OutputView', 'same', 'FillValues', fillValue);
end
