function residual=measure_residual_phase(anchor,pyramid,macroDisplacement,cfg)
% MEASURE_RESIDUAL_PHASE 在 integer macro coordinate 上读取细相位残差。
% 不重采样原图，也不插值 wrapped phase angle；WLS 直接读取复响应。
integerCenter=anchor.center+round(macroDisplacement(:).'); sub=phase_subpixel_wls(anchor,pyramid,integerCenter,cfg);
residual=struct('dVib',sub.delta,'valid',sub.valid,'residualRms',sub.residualRms,...
    'sampleCount',sub.sampleCount,'integerCenter',integerCenter);
end
