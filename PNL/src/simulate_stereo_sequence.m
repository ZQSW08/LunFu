function [images, truth] = simulate_stereo_sequence(cfg, noiseSigma, motion)
%SIMULATE_STEREO_SEQUENCE 按论文仿真框架生成双目图像序列与真值。
%   采用平面纹理的透视单应映射，加入超采样、光学模糊和高斯噪声。
%   motion 可选；缺省时使用论文 Fig. 5 的耦合运动。

if nargin < 2 || isempty(noiseSigma)
    noiseSigma = 0;
end
if nargin < 3 || isempty(motion)
    motion = motion_trajectory(cfg, cfg.nFrames);
end

[texture, xGrid, yGrid] = make_crossline_texture(cfg);
H = cfg.roiSize(1);
W = cfg.roiSize(2);
N = size(motion, 2);
images = cell(1, 2);
images{1} = zeros(H, W, N, 'single');
images{2} = zeros(H, W, N, 'single');
truth.center3d = zeros(3, N);
truth.uv = zeros(2, N, 2);
truth.displacement3d = zeros(3, N);
truth.motion = motion;

for k = 1:N
    center = cfg.marker.center + motion(:, k);
    truth.center3d(:, k) = center;
    truth.displacement3d(:, k) = center - cfg.marker.center;
    for cam = 1:2
        % 裁剪区域使用完整图像坐标，因此投影得到的位移仍是 pixels。
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
        images{cam}(:, :, k) = single(min(max(frame, 0), 1));
        truth.uv(:, k, cam) = project_point(cfg.P{cam}, center);
    end
end
end

function motion = motion_trajectory(cfg, nFrames)
t = (0:nFrames - 1) / cfg.fps;
motion = zeros(3, nFrames);
switch lower(cfg.motion.type)
    case 'coupled'
        motion(1, :) = cfg.motion.xAmplitude * sin(2 * pi * cfg.motion.xFrequency * t);
        active = t >= cfg.motion.zStart;
        motion(3, active) = cfg.motion.zAmplitude * sin(2 * pi * cfg.motion.zFrequency * t(active));
    case 'amplitude'
        amp = cfg.motion.amplitude;
        motion(3, :) = amp * exp(0.35 * t) .* sin(2 * pi * cfg.motion.frequency * t);
    otherwise
        error('未知运动类型：%s', cfg.motion.type);
end
end

function uv = project_point(P, X)
q = P * [X; 1];
uv = q(1:2) / q(3);
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
