function dMacro=estimate_macro_bandprotected(dTotal,fps,vibrationBandHz)
% ESTIMATE_MACRO_BANDPROTECTED 在指定振动频带之前建立低通宏观跟随器。
% 截止频率取 fLow 的 0.8 倍，使目标频带内的宏观增益接近 0；
% 该实现推断适合“macro 慢、vibration 快”的可辨识条件。
band=sort(double(vibrationBandHz(:).')); if numel(band)~=2, error('vibrationBandHz 必须为 [fLow fHigh]。'); end
if band(1)<=0 || band(1)>=fps/2, error('vibrationBandHz 超出 Nyquist 范围。'); end
dMacro=estimate_macro_temporal(dTotal,fps,0.8*band(1));
end
