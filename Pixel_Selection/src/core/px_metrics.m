function metrics = px_metrics(signal, truthSignal, fs, truthPeakFrequency)
% 计算论文式PF、FE、PER、RMSE和PCC。
if nargin < 4 || isempty(truthPeakFrequency)
    truthPeakFrequency = [];
end
[frequency, spectrum] = px_normalize_spectrum(signal, fs);
[truthFrequency, truthSpectrum] = px_normalize_spectrum(truthSignal, fs);
sampleCount = min(numel(spectrum), numel(truthSpectrum));
spectrum = spectrum(1:sampleCount);
truthSpectrum = truthSpectrum(1:sampleCount);
frequency = frequency(1:sampleCount);
truthFrequency = truthFrequency(1:sampleCount);
[~, index] = max(spectrum);
[~, truthIndex] = max(truthSpectrum);
metrics.PF = frequency(index);
if isempty(truthPeakFrequency)
    truthPeakFrequency = truthFrequency(truthIndex);
end
metrics.FE = abs(metrics.PF - truthPeakFrequency);
metrics.PER = spectrum(index)^2 / max(sum(spectrum.^2), eps);
metrics.RMSE = sqrt(mean((spectrum - truthSpectrum).^2));
centered = spectrum - mean(spectrum);
truthCentered = truthSpectrum - mean(truthSpectrum);
metrics.PCC = sum(centered .* truthCentered) / max(sqrt(sum(centered.^2) * sum(truthCentered.^2)), eps);
metrics.frequency = frequency;
metrics.spectrum = spectrum;
metrics.truthSpectrum = truthSpectrum;
end
