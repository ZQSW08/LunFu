function [line, ok, diagnostics] = find_phase_zero_line(response, phaseMap, roughCenter, expectedAngleDeg, methodCfg)
%FIND_PHASE_ZERO_LINE 用双三次插值寻找最接近粗中心的零相位直线。
% 复现推断：用 Im(response)=0 且 Re(response)>0 的等值线近似 phase=0。
if nargin < 5, methodCfg = struct(); end
if ~isfield(methodCfg,'phaseOversampling'), methodCfg.phaseOversampling = 4; end
if ~isfield(methodCfg,'minValidLineSupport'), methodCfg.minValidLineSupport = 8; end
if ~isfield(methodCfg,'phaseDiagnostics'), methodCfg.phaseDiagnostics = false; end
scale = max(1,round(methodCfg.phaseOversampling)); [h,w] = size(phaseMap);
xq = 1:1/scale:w; yq = 1:1/scale:h;
% 只对虚部生成高分辨率图，因为 phase=0 的候选曲线由 Im(response)=0 决定。
% 网格持久化可避免视频帧之间重复创建相同的插值坐标。
persistent gridCache
if isempty(gridCache) || gridCache.h~=h || gridCache.w~=w || gridCache.scale~=scale
    [gridCache.Xq,gridCache.Yq] = meshgrid(xq,yq);
    gridCache.h=h; gridCache.w=w; gridCache.scale=scale;
end
imagHigh = interp2(1:w,1:h,imag(response),gridCache.Xq,gridCache.Yq,'cubic',NaN);
contourData = contourc(xq,yq,imagHigh,[0 0]); candidates = {}; idx = 1;
while idx < size(contourData,2)
    n = contourData(2,idx); stop = min(idx+n,size(contourData,2)); pts = contourData(:,idx+1:stop).'; idx = idx+n+1;
    if size(pts,1) < methodCfg.minValidLineSupport, continue; end
    % 实部只需在候选零交叉点上采样，不再对整幅图做第二次高分辨率插值。
    rv = interp2(1:w,1:h,real(response),pts(:,1),pts(:,2),'cubic',NaN);
    positive = isfinite(rv) & rv >= 0;
    if nnz(positive) >= methodCfg.minValidLineSupport, pts = pts(positive,:); end
    if size(pts,1) >= methodCfg.minValidLineSupport
        fit = fit_line_tls(pts); angle = mod(atan2d(-fit.a,fit.b),180);
        angleError = abs(mod(angle-expectedAngleDeg+90,180)-90);
        d = hypot(pts(:,1)-roughCenter(1),pts(:,2)-roughCenter(2));
        candidates{end+1} = struct('points',pts,'fit',fit,'distance',min(d), ...
            'angleError',angleError,'support',size(pts,1)); %#ok<AGROW>
    end
end
line = struct('a',NaN,'b',NaN,'c',NaN,'points',[],'support',0,'residual',Inf);
if methodCfg.phaseDiagnostics
    realHigh = interp2(1:w,1:h,real(response),gridCache.Xq,gridCache.Yq,'cubic',NaN);
    phaseHigh = atan2(imagHigh,realHigh);
else
    phaseHigh = [];
end
diagnostics = struct('phaseHigh',phaseHigh,'candidates',{candidates}, ...
    'selectedIndex',NaN,'expectedAngleDeg',expectedAngleDeg); ok = false;
if isempty(candidates), return; end
score = cellfun(@(s) s.distance+0.02*s.angleError,candidates);
[~,selected] = min(score); line = candidates{selected}.fit; diagnostics.selectedIndex = selected;
ok = isfinite(line.a) && line.support >= methodCfg.minValidLineSupport;
end
