function frames = apcv_generate_sequence(canvas, imageSize, margin, displacementPx, noiseSigma, illuminationDrift, seed, direction)
%APCV_GENERATE_SEQUENCE 根据已知真值位移生成图像序列。
% 原始 canvas 不被修改；每帧统一做全图平移、照明变化和加性噪声。

if nargin < 8 || isempty(direction)
    direction = 'vertical';
end

rng(seed, 'twister');
n = numel(displacementPx);
frames = zeros(imageSize(1), imageSize(2), n, 'single');
rows = margin + (1:imageSize(1));
cols = margin + (1:imageSize(2));

for k = 1:n
    moved = apcv_shift_image(canvas, displacementPx(k), direction);
    roi = moved(rows, cols);
    illumination = 1 + illuminationDrift * sin(2*pi*(k-1)/max(n-1,1));
    roi = illumination * roi + noiseSigma * randn(size(roi));
    frames(:, :, k) = single(min(max(roi, 0), 1));
end
end
