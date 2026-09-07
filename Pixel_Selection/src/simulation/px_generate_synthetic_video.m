function [video, truth] = px_generate_synthetic_video(cfg)
% 生成带结构振动、相机漂移和短时扰动的可重复合成视频。
% 该视频用于验证信号处理链，不冒充论文真实硬件实验数据。
rng(cfg.synthetic.seed, 'twister');
frames = cfg.synthetic.frames;
height = cfg.synthetic.height;
width = cfg.synthetic.width;
fs = cfg.synthetic.fs;
[xx, yy] = meshgrid(1:width, 1:height);

background = 0.30 + 0.008 * sin(xx / 9) + 0.006 * cos(yy / 11);
background(13:24, 19:42) = background(13:24, 19:42) + 0.12;
noise = randn(height, width);
% 用小卷积近似固定背景纹理，保持结构目标与背景的纹理差异。
kernel = ones(3, 3) / 9;
background = background + 0.006 * conv2(noise, kernel, 'same');

targetMask = false(height, width);
targetMask(36:105, 63:132) = true;
target = 0.58 + 0.25 * sin(xx / 2.2) + 0.18 * cos(yy / 3.7);
target = target + 0.08 * sin((xx + yy) / 1.8);
target = min(max(target, 0), 1);

times = (0:frames-1)' / fs;
vibration = cfg.synthetic.amplitudePixels * sin(2 * pi * cfg.synthetic.frequency * times);
cameraDx = 0.16 * sin(2 * pi * 0.65 * times) + 0.05 * sin(2 * pi * 1.7 * times);
cameraDy = 0.12 * cos(2 * pi * 0.45 * times);
burst = exp(-0.5 * ((times - 1.85) / 0.055).^2);
cameraDx = cameraDx + 0.8 * burst;
cameraDy = cameraDy - 0.5 * burst;

video = zeros(height, width, frames, 'single');
for frameIndex = 1:frames
    movingTarget = px_warp_image(target, 0, vibration(frameIndex));
    frame = single(background);
    frame(~targetMask) = single(background(~targetMask));
    frame(targetMask) = movingTarget(targetMask);
    frame = px_warp_image(frame, cameraDx(frameIndex), cameraDy(frameIndex));
    frame = frame + single(0.006 * randn(height, width));
    video(:, :, frameIndex) = min(max(frame, 0), 1);
end

truth.times = times;
truth.vibration = vibration;
truth.cameraDx = cameraDx;
truth.cameraDy = cameraDy;
truth.targetMask = targetMask;
truth.frequency = cfg.synthetic.frequency;
truth.fs = fs;
end
