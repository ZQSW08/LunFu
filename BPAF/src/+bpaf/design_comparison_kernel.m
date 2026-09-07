function [kernel, info] = design_comparison_kernel(method, fs, estimatedFrequency)
%DESIGN_COMPARISON_KERNEL 按论文表1生成 Acc2017/2018/2022 的 LoG 核。

normalizedFrequency = estimatedFrequency / fs;
switch lower(method)
    case 'acc2017'
        sigma = 1 / (8*normalizedFrequency);
    case 'acc2018'
        sigma = 1 / (4*sqrt(2)*normalizedFrequency);
    case 'acc2022'
        sigma = sqrt(2) / (2*pi*normalizedFrequency);
    otherwise
        error('未知对比方法：%s', method);
end

halfWidth = min(250, max(6, ceil(5*sigma)));
t = -halfWidth:halfWidth;
g = exp(-(t.^2)/(2*sigma^2)) / (sqrt(2*pi)*sigma);
kernel = ((t.^2-sigma^2)/sigma^4) .* g;
kernel = kernel - mean(kernel);
nfft = max(8192, 2^nextpow2(numel(kernel)*16));
response = abs(fft(kernel, nfft));
kernel = kernel / max(response(1:floor(nfft/2)+1));

info = struct('method', method, 'sigmaSamples', sigma, ...
    'estimatedFrequencyHz', estimatedFrequency, 'timeIndex', t, ...
    'kernelLength', numel(kernel));
end
