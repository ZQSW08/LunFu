function canvas = apcv_generate_texture(imageSize, margin, seed, style)
%APCV_GENERATE_TEXTURE 生成具有跨尺度纹理的可重复合成观测背景。
% 纹理同时包含连续随机结构、清晰边缘和局部标记，避免只验证单一图案。

rng(seed, 'twister');
h = imageSize(1) + 2 * margin;
w = imageSize(2) + 2 * margin;
[x, y] = meshgrid(1:w, 1:h);

fine = imgaussfilt(randn(h, w), 0.7);
medium = imgaussfilt(randn(h, w), 2.4);
coarse = imgaussfilt(randn(h, w), 7.5);
canvas = 0.24 * mat2gray(fine) + 0.31 * mat2gray(medium) + ...
    0.24 * mat2gray(coarse);

% 竖向位移的幅度粗配准依赖逐行高频能量；加入非周期行特征，
% 避免规则条纹导致互相关出现等高伪峰。
rowSignature = zeros(h, 1);
rowCoordinate = (1:h)';
for k = 1:26
    center = randi([8, h-8]);
    width = 0.7 + 2.2*rand;
    amplitude = 0.25 + 0.75*rand;
    rowSignature = rowSignature + amplitude * ...
        exp(-0.5*((rowCoordinate-center)/width).^2);
end
rowSignature = mat2gray(rowSignature);
canvas = canvas + 0.52 * repmat(rowSignature, 1, w);

% 添加方向丰富的确定性结构，使不同金字塔方向均包含有效能量。
canvas = canvas + 0.08 * sin(2*pi*x/17) + 0.02 * cos(2*pi*y/23) ...
    + 0.05 * sin(2*pi*(x+y)/31);

switch lower(style)
    case 'lab'
        canvas = canvas + 0.18 * (mod(floor(x/28), 2) == 0);
        canvas = canvas + 0.03 * (mod(floor(y/34), 2) == 0);
        for k = 1:14
            cx = randi([15, w-15]); cy = randi([15, h-15]);
            radius = randi([3, 9]);
            canvas((x-cx).^2 + (y-cy).^2 <= radius^2) = 0.08 + 0.85*rand;
        end
    case 'bridge'
        canvas = canvas + 0.13 * (abs(y - 0.62*h) < 6);
        canvas = canvas + 0.10 * (abs(y - (0.30*h + 0.08*x)) < 4);
        canvas = canvas + 0.10 * (mod(floor(x/19 + y/27), 2) == 0);
        for k = 1:18
            cx = randi([12, w-12]); cy = randi([12, h-12]);
            sx = randi([3, 12]); sy = randi([2, 8]);
            canvas(abs(x-cx) <= sx & abs(y-cy) <= sy) = 0.10 + 0.80*rand;
        end
    otherwise
        error('未知纹理类型: %s', style);
end

canvas = mat2gray(canvas);
canvas = imadjust(canvas, stretchlim(canvas, [0.01 0.99]), [0 1]);
end
