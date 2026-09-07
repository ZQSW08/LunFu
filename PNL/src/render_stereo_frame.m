function [frames, uv] = render_stereo_frame(cfg, center, texture, xGrid, yGrid, noiseSigma)
%RENDER_STEREO_FRAME 渲染一个同步双目帧，用于序列仿真和视频写出。

if nargin < 6
    noiseSigma = 0;
end
H = cfg.roiSize(1);
W = cfg.roiSize(2);
frames = cell(1, 2);
uv = zeros(2, 2);
for cam = 1:2
    u = cfg.roiCenter(1, cam) + ((1:W) - (W + 1) / 2);
    v = cfg.roiCenter(2, cam) + ((1:H)' - (H + 1) / 2);
    [U, V] = meshgrid(u, v);
    uvCrop = [U(:)'; V(:)'; ones(1, numel(U))];
    Hplane = cfg.P{cam} * [eye(3, 2), center; 0, 0, 1];
    q = Hplane \ uvCrop;
    x = reshape(q(1, :) ./ q(3, :), H, W);
    y = reshape(q(2, :) ./ q(3, :), H, W);
    tx = interp1(xGrid, 1:numel(xGrid), x, 'linear', NaN);
    ty = interp1(yGrid, 1:numel(yGrid), y, 'linear', NaN);
    frame = interp2(1:numel(xGrid), 1:numel(yGrid), texture, tx, ty, 'linear', 0);
    frame = gaussian_blur(frame, cfg.render.blurSigma);
    if noiseSigma > 0
        frame = frame + (noiseSigma / 255) * randn(size(frame));
    end
    frames{cam} = single(min(max(frame, 0), 1));
    q = cfg.P{cam} * [center; 1];
    uv(:, cam) = q(1:2) / q(3);
end
end

function out = gaussian_blur(im, sigma)
if sigma <= 0
    out = im;
    return
end
radius = max(1, ceil(3 * sigma));
x = -radius:radius;
k = exp(-(x .^ 2) / (2 * sigma ^ 2));
k = k / sum(k);
out = conv2(conv2(im, k, 'same'), k', 'same');
end
