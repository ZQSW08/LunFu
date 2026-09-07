function [video, field] = generate_mode_video(reference, time, mode, cfg)
%GENERATE_MODE_VIDEO 生成具有空间模态的等价全场振动视频。
% 对每一帧采用反向插值 I_t(x,y)=I_0(x-dx,y-dy)，从而保留场真值。
[height, width] = size(reference);
[x, y] = meshgrid(1:width, 1:height);
frames = numel(time);
video = zeros(height, width, frames);
field = zeros(height, width, frames);
for k = 1:frames
    temporal = sin(2*pi*cfg.synthetic.frequency*time(k));
    displacement = cfg.synthetic.amplitude * mode * temporal;
    field(:,:,k) = displacement;
    % 垂直位移：行坐标 y 减去位移即得到向下移动的图像。
    video(:,:,k) = interp2(x, y, reference, x, y-displacement, 'linear', 0);
end
if cfg.synthetic.noiseStd > 0
    video = video + cfg.synthetic.noiseStd*randn(size(video));
end
video = min(max(video, 0), 1);
end
