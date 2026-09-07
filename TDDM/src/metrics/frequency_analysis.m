function out = frequency_analysis(x, fs)
%FREQUENCY_ANALYSIS 计算论文式单边幅度谱，不计算 PSD。
% 频谱定义：去均值后直接 FFT，输出非负频率的单边幅度 |X|/N；
% 该定义与“幅度-频率”图一致，不能用功率谱密度的单位或图形解释。
x = double(x(:));
if nargin < 2 || ~isscalar(fs) || ~isfinite(fs) || fs <= 0
    error('frequency_analysis:InvalidSamplingRate', 'fs 必须为正的有限采样频率。');
end
if isempty(x)
    out = struct('frequency', [], 'amplitude', [], 'noiseFloorMean', NaN, ...
        'noiseFloorMedian', NaN, 'spectrumType', 'single_sided_amplitude_fft', ...
        'normalizedAmplitude', [], 'normalizationReference', NaN, ...
        'isPSD', false, 'meanRemoved', true, 'nSamples', 0, ...
        'samplingFrequencyHz', fs, 'frequencyResolutionHz', NaN, 'nyquistHz', fs/2);
    return;
end
if any(~isfinite(x))
    error('frequency_analysis:NonFiniteInput', ...
        '频谱输入包含 NaN/Inf；请先记录并处理失效帧。');
end
x = x - mean(x);
N = numel(x);
X = fft(x);
P2 = abs(X / N);
nHalf = floor(N / 2) + 1;
P1 = P2(1:nHalf);
if numel(P1) > 2
    P1(2:end-1) = 2 * P1(2:end-1);
end
f = fs * (0:nHalf-1)' / N;
normalizationReference=max(P1);
if isfinite(normalizationReference) && normalizationReference>0
    normalizedAmplitude=P1/normalizationReference;
else
    normalizedAmplitude=zeros(size(P1));
end
% 论文正文与表格对 noise floor 的统计文字不完全一致，两个值均保留。
if numel(P1) > 2
    noiseRegion = P1(2:end);
else
    noiseRegion = P1;
end
out = struct('frequency', f, 'amplitude', P1, ...
    'noiseFloorMean', mean(noiseRegion), 'noiseFloorMedian', median(noiseRegion), ...
    'normalizedAmplitude', normalizedAmplitude, 'normalizationReference', normalizationReference, ...
    'spectrumType', 'single_sided_amplitude_fft', 'isPSD', false, ...
    'meanRemoved', true, 'nSamples', N, 'samplingFrequencyHz', fs, ...
    'frequencyResolutionHz', fs/N, 'nyquistHz', fs/2);
end
