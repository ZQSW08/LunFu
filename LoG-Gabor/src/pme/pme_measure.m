function result = pme_measure(video, params, cfg, pixel, theta0)
%PME_MEASURE 根据论文 Eq. (7)-(10) 从局部相位恢复位移。
% pixel=[row,column]；theta0 为滤波器方向。输出保留 wrapped/unwrapped 等
% 中间量，便于定位 phase wrapping 与累积漂移问题。
if nargin < 5 || isempty(theta0), theta0 = cfg.loggabor.theta0; end
[~, phase, response, meta] = loggabor_response(video, params, cfg, theta0);
row = pixel(1); col = pixel(2);
rawPhase = squeeze(phase(row,col,:));
wrappedDifference = angle(exp(1i*diff(rawPhase)));
unwrappedPhase = unwrap(rawPhase);
unwrappedDifference = diff(unwrappedPhase);
omega = meta.omega;
increment = -unwrappedDifference / omega;
cumulative = [0; cumsum(increment)];
result.displacement = cumulative;
result.rawPhase = rawPhase;
result.wrappedDifference = wrappedDifference;
result.unwrappedDifference = unwrappedDifference;
result.increment = increment;
result.response = squeeze(response(row,col,:));
result.amplitude = abs(result.response);
result.meta = meta;
end
