function [texture, xGrid, yGrid] = make_crossline_texture(cfg)
%MAKE_CROSSLINE_TEXTURE 生成论文中 16 mm x 16 mm 的十字线标记。
%   输出纹理坐标单位为 mm，纹理灰度范围为 [0,1]。

n = cfg.marker.textureSamples;
halfSize = cfg.marker.size / 2;
xGrid = linspace(-halfSize, halfSize, n);
yGrid = linspace(halfSize, -halfSize, n); % 行坐标向下，物理 y 轴向上
[X, Y] = meshgrid(xGrid, yGrid);

lineHalf = cfg.marker.lineWidth / 2;
lineHalfLength = cfg.marker.lineLength / 2;
horizontal = abs(Y) <= lineHalf & abs(X) <= lineHalfLength;
vertical = abs(X) <= lineHalf & abs(Y) <= lineHalfLength;

% 用少量固定纹理起伏避免完全理想的二值图像掩盖相位梯度问题。
texture = 0.03 + 0.97 * double(horizontal | vertical);
texture = texture + 0.004 * sin(2 * pi * X / 2.7) .* cos(2 * pi * Y / 3.1);
texture = min(max(texture, 0), 1);
end
