function data = generate_dataset(spec, cfg)
%GENERATE_DATASET 生成带已知真值的图像序列和可播放视频。
% 位移以像素表达；运动频率、采样率、时长及大/小运动幅值比按论文设置。

matPath = fullfile(cfg.dataDir, [lower(spec.id), '.mat']);
videoPath = fullfile(cfg.videoDir, [lower(spec.id), '.avi']);
if isfile(matPath) && isfile(videoPath) && ~cfg.forceRegenerate
    data = load(matPath);
    data.matPath = matPath;
    data.videoPath = videoPath;
    return;
end

rng(cfg.randomSeed + sum(double(spec.id)), 'twister');
nFrames = round(spec.fs * spec.duration);
t = (0:nFrames-1)' / spec.fs;
[largeMotion, vibration] = motion_signals(spec, t);
totalMotion = largeMotion + vibration;

[xx, yy] = meshgrid(1:spec.width, 1:spec.height);
% MAT 数据保留单精度灰度，避免 8 bit 量化吞没 0.02 px 级的相位变化；
% 可播放 AVI 仍按常规 8 bit 编码导出。
frames = zeros(spec.height, spec.width, nFrames, 'single');
writer = VideoWriter(videoPath, 'Motion JPEG AVI');
writer.FrameRate = spec.fs;
writer.Quality = cfg.videoQuality;
open(writer);
cleanup = onCleanup(@() close_writer(writer));

for frameIdx = 1:nFrames
    frame = render_frame(xx, yy, totalMotion(frameIdx), spec, frameIdx);
    frames(:, :, frameIdx) = single(frame);
    rgb = repmat(im2uint8(frame), 1, 1, 3);
    writeVideo(writer, rgb);
end
close(writer);
clear cleanup;

truth = struct();
truth.time = t;
truth.largeMotionPx = largeMotion;
truth.vibrationPx = vibration;
truth.totalMotionPx = totalMotion;
truth.fs = spec.fs;
truth.targetFrequency = spec.targetFrequency;
truth.proxy = spec.proxy;
truth.description = spec.description;
save(matPath, 'frames', 'truth', 'spec', '-v7.3');

data = struct('frames', frames, 'truth', truth, 'spec', spec, ...
    'matPath', matPath, 'videoPath', videoPath);
end

function [largeMotion, vibration] = motion_signals(spec, t)
switch upper(spec.id)
    case 'SV1'
        % 论文式(34)：0.01 sin(40*pi*t) + 5t；2 px/m 保持幅值比 2500。
        largeMotion = 2.0 * (5 * t);
        vibration = 2.0 * 0.01 * sin(40 * pi * t);
    case 'SV2'
        % 论文式(35)：0.01 sin(40*pi*t) + 50/(1+exp(-0.75t))-25。
        largeMotion = 2.0 * (50 ./ (1 + exp(-0.75 * t)) - 25);
        vibration = 2.0 * 0.01 * sin(40 * pi * t);
    case 'EXCITER_PROXY'
        % 40 px 整体位移与 0.05 px 微振幅对应论文讨论中的约 800 倍幅值比。
        u = t / max(t);
        largeMotion = 40 * (3*u.^2 - 2*u.^3);
        vibration = 0.05 * sin(2*pi*30.7*t);
    case 'BEAM_MOVING_PROXY'
        % 40 px 整体位移与 0.4 px 初始振幅对应约 100 倍幅值比。
        u = t / max(t);
        largeMotion = 40 * (3*u.^2 - 2*u.^3);
        vibration = 0.4 * exp(-0.22*t) .* sin(2*pi*5.3*t);
    case 'BEAM_STATIC_PROXY'
        largeMotion = zeros(size(t));
        vibration = 0.4 * exp(-0.22*t) .* sin(2*pi*5.3*t);
    otherwise
        error('未知数据集：%s', spec.id);
end
end

function frame = render_frame(xx, yy, displacement, spec, frameIdx)
% 用亚像素解析表达式生成纹理目标，避免整数平移吞掉微振动。
carrierPeriod = 8;
centerX = 38 + displacement;
centerY = spec.height / 2;
% 整幅纹理随目标共同运动，对应论文式(1)-(3)的平移成像模型，也可解释为
% 相机存在大运动。这样既保留可见目标，又避免空白背景像素的随机相位淹没
% 2500:1 幅值比下的微振动。
movingCarrier = 0.46 + 0.20*cos(2*pi*(xx-displacement)/carrierPeriod) ...
    + 0.06*cos(2*pi*(yy-centerY)/13);

switch spec.targetType
    case 'ball'
        radius = 15;
        distance = sqrt((xx-centerX).^2 + (yy-centerY).^2);
        mask = 1 ./ (1 + exp((distance-radius)/0.7));
    case 'plate'
        halfW = 22;
        halfH = 14;
        dx = abs(xx-centerX) - halfW;
        dy = abs(yy-centerY) - halfH;
        mask = 1 ./ (1 + exp(max(dx, dy)/0.7));
    case 'beam'
        halfW = 26;
        halfH = 5;
        dx = abs(xx-centerX) - halfW;
        dy = abs(yy-centerY) - halfH;
        mask = 1 ./ (1 + exp(max(dx, dy)/0.55));
    otherwise
        error('未知目标类型：%s', spec.targetType);
end

frame = movingCarrier + 0.005*mask;
% 固定随机种子下加入轻微成像噪声和弱光照漂移，模拟真实视频但不改变真值。
frame = frame + 1e-5*randn(size(frame)) + 0.0002*sin(2*pi*frameIdx/311);
frame = min(max(frame, 0), 1);
end

function close_writer(writer)
try
    close(writer);
catch
end
end
