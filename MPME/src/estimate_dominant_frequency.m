function [frequency, spectrumFrequency, spectrumAmplitude] = estimate_dominant_frequency(signal, fps, searchRange)
%ESTIMATE_DOMINANT_FREQUENCY Windowed FFT with parabolic peak interpolation.

if nargin < 3 || isempty(searchRange), searchRange = [0.05 fps/2]; end
signal = double(signal(:));
signal = detrend(signal, 1);
sampleCount = numel(signal);
window = hann(sampleCount, 'periodic');
fftValue = fft(signal .* window);
halfCount = floor(sampleCount / 2) + 1;
spectrumFrequency = (0:halfCount-1).' * fps / sampleCount;
spectrumAmplitude = abs(fftValue(1:halfCount));
valid = spectrumFrequency >= searchRange(1) & spectrumFrequency <= searchRange(2);
validIndices = find(valid);
[~, localPeak] = max(spectrumAmplitude(valid));
peakIndex = validIndices(localPeak);
frequency = spectrumFrequency(peakIndex);
if peakIndex > 1 && peakIndex < halfCount
    left = spectrumAmplitude(peakIndex-1);
    centre = spectrumAmplitude(peakIndex);
    right = spectrumAmplitude(peakIndex+1);
    denominator = left - 2*centre + right;
    if abs(denominator) > eps
        offset = 0.5 * (left - right) / denominator;
        % 仅在峰值相邻频点之间插值，避免边缘/平坦谱把结果外推成负频率。
        offset = min(max(offset,-0.5),0.5);
        frequency = (peakIndex - 1 + offset) * fps / sampleCount;
    end
end
frequency = min(max(frequency,searchRange(1)),searchRange(2));
end
