function [shiftXY, quality, diagnostics] = phase_correlation_shift(reference, current, maxShift)
%PHASE_CORRELATION_SHIFT 用归一化互功率谱估计二维整数平移。
% shiftXY=[dx dy] 表示 current 相对 reference 向右/向下的位移。
if nargin < 3 || isempty(maxShift), maxShift = Inf; end
reference = localGrayDouble(reference);
current = localGrayDouble(current);
if ~isequal(size(reference),size(current))
    error('phase_correlation_shift 的两幅图尺寸必须一致。');
end
[h,w] = size(reference);
wy = localHann(h); wx = localHann(w);
window = wy*wx';
reference = (reference-mean(reference(:))).*window;
current = (current-mean(current(:))).*window;
f0 = fft2(reference); f1 = fft2(current);
crossPower = f1.*conj(f0);
crossPower = crossPower./max(abs(crossPower),1e-12);
surface = fftshift(real(ifft2(crossPower)));
cy = floor(h/2)+1; cx = floor(w/2)+1;
if isfinite(maxShift)
    [xx,yy] = meshgrid(1:w,1:h);
    surface(hypot(xx-cx,yy-cy)>maxShift) = -Inf;
end
[peakValue,index] = max(surface(:));
[py,px] = ind2sub(size(surface),index);
shiftXY = [px-cx, py-cy];
guard = surface;
y1=max(1,py-2); y2=min(h,py+2); x1=max(1,px-2); x2=min(w,px+2);
guard(y1:y2,x1:x2)=NaN;
sidelobe = guard(isfinite(guard));
if isempty(sidelobe)
    psr = 0;
else
    psr = (peakValue-mean(sidelobe))/max(std(sidelobe),1e-9);
end
quality = min(1,max(0,(psr-2)/10));
diagnostics = struct('peak',peakValue,'psr',psr,'surface',surface);
end

function value = localGrayDouble(value)
if ndims(value)==3, value=rgb2gray(value); end
value=im2double(value);
end

function w = localHann(n)
if n<=1, w=ones(n,1); else, w=0.5-0.5*cos(2*pi*(0:n-1)'/(n-1)); end
end
