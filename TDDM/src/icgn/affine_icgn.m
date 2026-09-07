function [q, info] = affine_icgn(reference, current, refCenter, q0, cfg)
%AFFINE_ICGN TDDM IC-GN 统一入口，默认优先使用 ADIC2D 进行数值求解。
% 如果第三方代码在特定输入上失败，自动回退到同接口的原生实现并记录 engine。
engine = 'native';
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
adic2dPath = fullfile(projectRoot, 'third_party', 'ADIC2D');
if isfolder(adic2dPath) && exist('SFExpressions', 'file') ~= 2
    addpath(adic2dPath);
end
if isfield(cfg.impl, 'icgnModel') && strcmpi(cfg.impl.icgnModel, 'translation')
    [q, info] = translation_icgn(reference, current, refCenter, q0, cfg);
    return;
end
if isfield(cfg.impl, 'icgnEngine')
    engine = lower(char(cfg.impl.icgnEngine));
end
if strcmp(engine, 'adic2d') && cfg.impl.useZNNormalization
    try
        [q, info] = adic2d_affine_icgn(reference, current, refCenter, q0, cfg);
        return;
    catch ME
        warning('TDDM:ADIC2DFallback', 'ADIC2D failed (%s); using native IC-GN.', ME.message);
    end
end
[q, info] = affine_icgn_native(reference, current, refCenter, q0, cfg);
end
