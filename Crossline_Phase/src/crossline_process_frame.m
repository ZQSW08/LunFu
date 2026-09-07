function result = crossline_process_frame(I, cfg, previousGeometry)
%CROSSLINE_PROCESS_FRAME 单帧：粗检测 -> Gabor phase -> 两条零相位线 -> 中心。
% previousGeometry 只保留接口，论文 baseline 不使用跨帧相位或累积位移。
if nargin < 3, previousGeometry = []; end %#ok<INUSD>
[geometry,BW,coarseDiagnostics] = crossline_detect_coarse(I,cfg.coarse);
result = struct('valid',false,'center',[NaN NaN],'geometry',geometry,'BW',BW, ...
    'coarseDiagnostics',coarseDiagnostics,'responses',{{}},'phaseMaps',{{}}, ...
    'zeroLines',{{}},'zeroDiagnostics',{{}},'message','');
if ~geometry.valid, result.message = coarseDiagnostics.message; return; end
for k = 1:2
    [G,gaborMeta] = build_complex_gabor(geometry.lineAnglesDeg(k),geometry.lineWidthsPx(k), ...
        geometry.lineLengthsPx(k),cfg.method);
    [response,phaseMap] = extract_phase(I,G,gaborMeta,cfg.method);
    [zeroLine,ok,zdiag] = find_phase_zero_line(response,phaseMap,geometry.roughCenter, ...
        geometry.lineAnglesDeg(k),cfg.method);
    zeroLine.gabor = gaborMeta; result.responses{k} = response; result.phaseMaps{k} = phaseMap;
    result.zeroLines{k} = zeroLine; result.zeroDiagnostics{k} = zdiag;
    if ~ok, result.message = sprintf('第 %d 条 phase zero-crossing 未找到。',k); return; end
end
[center,ok,intersectionDiagnostics] = intersect_phase_lines(result.zeroLines{1},result.zeroLines{2});
result.intersectionDiagnostics = intersectionDiagnostics; result.center = center;
result.valid = ok && all(isfinite(center));
if ~result.valid, result.message = 'phase zero-crossing 两直线交点无效。'; end
end
