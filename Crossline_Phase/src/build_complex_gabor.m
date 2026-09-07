function [G, meta] = build_complex_gabor(lineAngleDeg, lineWidthPx, lineLengthPx, methodCfg)
%BUILD_COMPLEX_GABOR 根据当前 crossline 几何参数构造二维复 Gabor。
% 论文明确：滤波器方向与线方向垂直；此处 alpha 是 carrier normal 角度。
if nargin < 4, methodCfg = struct(); end
if ~isfield(methodCfg, 'gaborPeriodFactor'), methodCfg.gaborPeriodFactor = 2; end
if ~isfield(methodCfg, 'sigmaCoverage'), methodCfg.sigmaCoverage = 6; end
lineWidthPx = max(double(lineWidthPx), 0.5);
lineLengthPx = max(double(lineLengthPx), 8);
carrierAngleDeg = mod(double(lineAngleDeg) + 90, 180);
alpha = deg2rad(carrierAngleDeg);
gaborPeriodPx = methodCfg.gaborPeriodFactor * lineWidthPx;
gaborFreqCyclesPerPx = 1 / gaborPeriodPx;
sigmaR = lineLengthPx / methodCfg.sigmaCoverage;
sigmaA = lineLengthPx / methodCfg.sigmaCoverage;
halfSize = max(4, ceil(3 * max(sigmaR, sigmaA)));
[x, y] = meshgrid(-halfSize:halfSize, -halfSize:halfSize);
u = x*cos(alpha) + y*sin(alpha);
v = -x*sin(alpha) + y*cos(alpha);
envelope = exp(-(u.^2/(2*sigmaR^2) + v.^2/(2*sigmaA^2)));
carrier = exp(1i * 2*pi*gaborFreqCyclesPerPx * u);
G = envelope .* carrier;
meta = struct('lineAngleDeg',lineAngleDeg,'carrierAngleDeg',carrierAngleDeg, ...
    'gaborPeriodPx',gaborPeriodPx,'gaborFreqCyclesPerPx',gaborFreqCyclesPerPx, ...
    'sigmaR',sigmaR,'sigmaA',sigmaA,'kernelSize',size(G), ...
    'separable',abs(sigmaR-sigmaA)<1e-12);
end
