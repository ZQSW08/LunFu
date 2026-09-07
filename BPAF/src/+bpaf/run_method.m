function result = run_method(features, method, prior, cfg, source, useGA)
%RUN_METHOD 统一运行 PVE、三种 LoG 对比方法或 BPAF。

arguments
    features struct
    method char
    prior double
    cfg struct
    source char = 'cube'
    useGA (1,1) logical = true
end

methodLower = lower(method);
switch methodLower
    case 'pve'
        kernel = [];
        kernelInfo = struct('method', 'PVE');
        useNS = false;
    case {'acc2017', 'acc2018', 'acc2022'}
        [kernel, kernelInfo] = bpaf.design_comparison_kernel(methodLower, features.fs, prior(1));
        useNS = strcmp(methodLower, 'acc2022');
    case 'bpaf'
        fl = prior(1);
        fh = prior(2);
        fhs = min(features.fs/2, fh+10);
        [kernel, kernelInfo] = bpaf.design_bpaf_kernel(features.fs, fl, fh, ...
            fhs, cfg.stopbandAlpha, cfg, useGA);
        useNS = true;
    case 'bp'
        fl = prior(1);
        fh = prior(2);
        fhs = min(features.fs/2, fh+10);
        [kernel, kernelInfo] = bpaf.design_bpaf_kernel(features.fs, fl, fh, ...
            fhs, cfg.stopbandAlpha, cfg, useGA);
        useNS = false;
    otherwise
        error('未知方法：%s', method);
end

filtered = bpaf.apply_motion_filter(features, kernel, useNS, source);
metrics = bpaf.evaluate_signal(filtered.signal, features.truthVibration, ...
    features.fs, filtered.marginSamples);
result = struct('method', method, 'prior', prior, 'kernel', kernel, ...
    'kernelInfo', kernelInfo, 'signal', filtered.signal, ...
    'marginSamples', filtered.marginSamples, 'metrics', metrics, ...
    'source', source, 'usedNonlinearSuppression', useNS);
end
