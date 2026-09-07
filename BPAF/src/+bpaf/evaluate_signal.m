function metrics = evaluate_signal(signal, truth, fs, marginSamples)
%EVALUATE_SIGNAL 计算论文式(31)-(33)的 PF、PER 与归一化波形 RMSE。

n = min(numel(signal), numel(truth));
signal = double(signal(1:n));
truth = double(truth(1:n));
marginSamples = min(marginSamples, floor((n-8)/2));
valid = (1+marginSamples):(n-marginSamples);
x = signal(valid);
y = truth(valid);

[frequency, spectrum] = one_sided_spectrum(x, fs);
[peakAmplitude, peakIdx] = max(spectrum);
pf = frequency(peakIdx);
per = peakAmplitude^2 / max(sum(spectrum.^2), eps);

xNorm = minmax_normalize(x);
yNorm = minmax_normalize(y);
rmseDirect = sqrt(mean((xNorm-yNorm).^2));
rmseFlipped = sqrt(mean(((1-xNorm)-yNorm).^2));
if rmseFlipped < rmseDirect
    xNorm = 1-xNorm;
    rmseValue = rmseFlipped;
    signValue = -1;
else
    rmseValue = rmseDirect;
    signValue = 1;
end

metrics = struct('PF', pf, 'PER', per, 'RMSE', rmseValue, ...
    'frequency', frequency, 'spectrum', spectrum/max(max(spectrum), eps), ...
    'validSignal', x, 'validTruth', y, 'normalizedSignal', xNorm, ...
    'normalizedTruth', yNorm, 'validIndices', valid, 'sign', signValue);
end

function [frequency, spectrum] = one_sided_spectrum(signal, fs)
n = numel(signal);
transform = fft(signal);
nPositive = floor(n/2)+1;
spectrum = abs(transform(1:nPositive));
frequency = (0:nPositive-1)' * fs/n;
spectrum = spectrum(:);
end

function output = minmax_normalize(input)
input = input(:);
output = (input-min(input)) / max(max(input)-min(input), eps);
end
