function [frequency, spectrum] = px_normalize_spectrum(signal, fs)
% 对信号去均值后计算单边幅值谱并归一化。
signal = double(signal(:));
signal = signal - mean(signal, 'omitnan');
n = numel(signal);
raw = abs(fft(signal));
last = floor(n / 2) + 1;
spectrum = raw(1:last);
frequency = (0:last-1)' * fs / n;
maximum = max(spectrum);
if maximum > 0
    spectrum = spectrum / maximum;
end
end
