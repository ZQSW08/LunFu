function [amplitude, phase, complexResponse, meta] = loggabor_response(video, params, cfg, theta0)
%LOGGABOR_RESPONSE 对视频逐帧执行 Eq. (5)，返回局部振幅和相位。
[height, width, frames] = size(video);
[filter, meta] = build_loggabor_filter(height, width, params, cfg, theta0);
complexResponse = zeros(height, width, frames);
for k = 1:frames
    spectrum = fftshift(fft2(video(:,:,k)));
    complexResponse(:,:,k) = ifft2(ifftshift(spectrum .* filter));
end
amplitude = abs(complexResponse);
phase = angle(complexResponse);
end
