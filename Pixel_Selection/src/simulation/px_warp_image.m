function output = px_warp_image(image, dx, dy)
% 使用双线性插值实现小幅平移，避免依赖图像处理工具箱。
[height, width] = size(image);
[xx, yy] = meshgrid(1:width, 1:height);
output = interp2(xx, yy, double(image), xx - dx, yy - dy, 'linear', 0);
output = single(output);
end
