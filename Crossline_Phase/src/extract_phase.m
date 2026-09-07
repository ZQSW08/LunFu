function [response, phaseMap] = extract_phase(I, G, gaborMeta, methodCfg)
%EXTRACT_PHASE 复 Gabor 卷积及四象限相位提取。
% 论文明确：phase = atan2(Im(r), Re(r))；MATLAB 的 angle 采用同一定义。
if ndims(I) == 3, I = rgb2gray(I); end
I = im2double(I);
useSeparable = nargin >= 3 && ~isempty(gaborMeta) && isfield(gaborMeta,'separable') && gaborMeta.separable;
if nargin >= 4 && isfield(methodCfg,'useSeparableGabor')
    useSeparable = useSeparable && methodCfg.useSeparableGabor;
end
if useSeparable
    % Gabor 包络在本工程中 sigmaR=sigmaA，因此 G(x,y)=gy(y)*gx(x)。
    % 两次一维卷积与二维 conv2 数值等价（误差仅为浮点舍入）。
    halfSize = (size(G,1)-1)/2; q = -halfSize:halfSize;
    alpha = deg2rad(gaborMeta.carrierAngleDeg);
    gx = exp(-(q.^2)/(2*gaborMeta.sigmaR^2)) .* ...
        exp(1i*2*pi*gaborMeta.gaborFreqCyclesPerPx*(q*cos(alpha)));
    gy = exp(-(q.^2)/(2*gaborMeta.sigmaA^2)) .* ...
        exp(1i*2*pi*gaborMeta.gaborFreqCyclesPerPx*(q*sin(alpha)));
    response = conv2(gy(:),gx(:).',I,'same');
else
    response = conv2(I, G, 'same');
end
phaseMap = angle(response);
end
