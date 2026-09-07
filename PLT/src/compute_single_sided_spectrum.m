function spectrum = compute_single_sided_spectrum(signal, fps, validMask)
% COMPUTE_SINGLE_SIDED_SPECTRUM 返回单边幅值谱，横轴与 processingFps 一致。
signal = double(signal(:));
if nargin<3 || isempty(validMask)
    validMask=isfinite(signal);
else
    validMask=logical(validMask(:)) & isfinite(signal);
end
validSampleCount=sum(validMask);
if nargin>=3 && validSampleCount<2
    spectrum=struct('frequencyHz',[],'amplitude',[],'validSampleCount',validSampleCount);
    return;
end
if nargin>=3 && any(~validMask)
    % 仅对短暂失效的间隙插值；全部失效已在上面直接返回空频谱。
    sampleIndex=(1:numel(signal)).';
    signal(~validMask)=interp1(sampleIndex(validMask),signal(validMask),sampleIndex(~validMask),'linear','extrap');
else
    signal(~isfinite(signal))=0;
end
n = numel(signal);
if n < 2 || fps <= 0
    spectrum = struct('frequencyHz', [], 'amplitude', [], 'validSampleCount', validSampleCount);
    return;
end
signal = detrend(signal, 1);
window = 0.5 - 0.5*cos(2*pi*(0:n-1)'/max(n-1,1));
normalization = sum(window);
y = fft(signal.*window);
oneSided = abs(y(1:floor(n/2)+1))/max(normalization,eps)*2;
oneSided(1) = oneSided(1)/2;
if mod(n,2)==0, oneSided(end)=oneSided(end)/2; end
spectrum = struct('frequencyHz',(0:floor(n/2))'*fps/n,'amplitude',oneSided,'validSampleCount',validSampleCount);
end
