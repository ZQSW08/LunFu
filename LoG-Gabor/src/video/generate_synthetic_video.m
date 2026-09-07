function [video, truth] = generate_synthetic_video(reference, displacement, cfg)
%GENERATE_SYNTHETIC_VIDEO 依据二维 Fourier shift theorem 生成亚像素视频。
% displacement 为 T×2，列分别是水平/垂直 pixel 位移；正值表示向右/向下。
% 论文 Eq. (11) 的排版没有给出可直接编码的离散频率索引，此处使用标准
% DFT 网格，避免把 fftshift/坐标方向混用。

[height, width] = size(reference);
frames = size(displacement, 1);
[fx, fy] = centered_frequency_grid(height, width);
referenceSpectrum = fftshift(fft2(reference));
video = zeros(height, width, frames, 'double');
for k = 1:frames
    phaseRamp = exp(-1i*2*pi*(fx*displacement(k,1) + fy*displacement(k,2)));
    frame = real(ifft2(ifftshift(referenceSpectrum .* phaseRamp)));
    video(:,:,k) = frame;
end
if isfield(cfg.synthetic, 'noiseStd') && cfg.synthetic.noiseStd > 0
    video = video + cfg.synthetic.noiseStd*randn(size(video));
end
video = min(max(video, 0), 1);
truth = displacement;
end

function [fx, fy] = centered_frequency_grid(height, width)
% centered_frequency_grid 与 fftshift 后的二维频谱逐元素对齐。
fxv = (-floor(width/2):ceil(width/2)-1) / width;
fyv = (-floor(height/2):ceil(height/2)-1) / height;
[fx, fy] = meshgrid(fxv, fyv);
end
