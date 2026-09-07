function result = px_run_pipeline(video, fs, outputRoot, truth, cfg, mode)
% 执行论文方法的完整链路，并保存中间数组、结果图和汇总结果。
if nargin < 5 || isempty(cfg)
    cfg = px_default_config();
end
if nargin < 6 || isempty(mode)
    mode = 'synthetic';
end
dirs = px_prepare_folders(outputRoot);
video = single(video);
if ndims(video) ~= 3
    error('输入视频必须为高度×宽度×帧数的三维灰度数组。');
end

csp = px_extract_csp(video, cfg);
foreground = px_foreground_mask(csp.foregroundResponse, cfg);
spatial = px_spatial_reliability(video, csp.phaseDifference, csp.amplitude, foreground, cfg);
temporal = px_temporal_reliability(csp.phaseDifference, spatial.reliable, cfg);
sparse = px_fista_reconstruction(temporal.difference, temporal.observed, fs, cfg);

truthAvailable = ~isempty(truth) && isfield(truth, 'vibration');
if truthAvailable
    truthDifference = diff(double(truth.vibration(:)));
    metrics = px_metrics(sparse.reconstructed, truthDifference, fs, truth.frequency);
    m1Signal = px_raw_signal(csp.phaseDifference, foreground.mask);
    m2Signal = px_raw_signal(csp.phaseDifference, spatial.reliable);
    m1 = px_metrics(m1Signal, truthDifference, fs, truth.frequency);
    m2 = px_metrics(m2Signal, truthDifference, fs, truth.frequency);
    temporalM3 = px_temporal_reliability(csp.phaseDifference, foreground.mask, cfg);
    sparseM3 = px_fista_reconstruction(temporalM3.difference, temporalM3.observed, fs, cfg);
    m3 = px_metrics(sparseM3.reconstructed, truthDifference, fs, truth.frequency);
    m4 = metrics;
    m1.rawSignal = m1Signal;
    m2.rawSignal = m2Signal;
    m3.rawSignal = sparseM3.reconstructed;
    m4.rawSignal = sparse.reconstructed;
    ablation = struct('M1_foreground_raw', m1, 'M2_spatial_raw', m2, ...
        'M3_temporal_sparse', m3, 'M4_full', m4);
else
    truthDifference = [];
    metrics = px_nan_metrics();
    ablation = struct();
    m1Signal = px_raw_signal(csp.phaseDifference, foreground.mask);
    m2Signal = px_raw_signal(csp.phaseDifference, spatial.reliable);
    sparseM3 = struct();
    temporalM3 = struct();
end

if cfg.io.saveIntermediate
    intermediate = struct();
    intermediate.phaseDifference = csp.phaseDifference;
    intermediate.amplitude = csp.amplitude;
    intermediate.foregroundResponse = csp.foregroundResponse;
    intermediate.foregroundCandidate = foreground.candidate;
    intermediate.foregroundUnion = foreground.union;
    intermediate.foregroundMask = foreground.mask;
    intermediate.foregroundThresholds = foreground.thresholds;
    intermediate.mei = spatial.mei;
    intermediate.sam = spatial.sam;
    intermediate.pse = spatial.pse;
    intermediate.confidenceMei = spatial.confidenceMei;
    intermediate.confidenceSam = spatial.confidenceSam;
    intermediate.confidencePse = spatial.confidencePse;
    intermediate.confidenceFused = spatial.confidenceFused;
    intermediate.reliable = spatial.reliable;
    intermediate.temporalSignal = temporal.signal;
    intermediate.temporalDifference = temporal.difference;
    intermediate.temporalRefined = temporal.refined;
    intermediate.temporalObserved = temporal.observed;
    intermediate.windowStd = temporal.windowStd;
    intermediate.windowRange = temporal.windowRange;
    intermediate.zStd = temporal.zStd;
    intermediate.zRange = temporal.zRange;
    intermediate.badWindows = temporal.badWindows;
    intermediate.frequencies = sparse.frequencies;
    intermediate.coefficients = sparse.coefficients;
    intermediate.reconstructed = sparse.reconstructed;
    intermediate.fftFrequency = sparse.fftFrequency;
    intermediate.fftSpectrum = sparse.fftSpectrum;
    save(fullfile(dirs.data, 'intermediate_outputs.mat'), '-struct', 'intermediate', '-v7.3');
end

if strcmpi(mode, 'synthetic') && truthAvailable
    save(fullfile(dirs.data, 'synthetic_case.mat'), 'video', 'truth', 'cfg', '-v7.3');
    if cfg.io.saveVideo
        px_write_video(video, fs, fullfile(dirs.videos, 'synthetic_case.mp4'));
    end
end
px_plot_outputs(video, fs, csp, foreground, spatial, temporal, sparse, truth, ablation, dirs, cfg);

summary.status = [lower(mode), '_equivalent_validation'];
summary.mode = mode;
summary.frameCount = size(video, 3);
summary.frameRateHz = fs;
summary.direction = csp.direction;
summary.orientationCandidates = csp.orientationCandidates;
summary.selectedOrientation = csp.orientation;
summary.sigmaPixels = csp.sigma;
summary.foregroundPixels = foreground.pixelCount;
summary.reliablePixels = spatial.pixelCount;
summary.spatialFallbackUsed = spatial.usedFallback;
summary.temporalBadWindows = nnz(temporal.badWindows);
summary.temporalWindowCount = numel(temporal.badWindows);
summary.sparseIterations = sparse.iterations;
summary.fftPeakFrequencyHz = sparse.peakFrequency;
summary.coefficientPeakFrequencyHz = sparse.coefficientPeakFrequency;
summary.metrics = px_metric_scalars(metrics);
if truthAvailable
    summary.ablation = struct('M1_foreground_raw', px_metric_scalars(ablation.M1_foreground_raw), ...
        'M2_spatial_raw', px_metric_scalars(ablation.M2_spatial_raw), ...
        'M3_temporal_sparse', px_metric_scalars(ablation.M3_temporal_sparse), ...
        'M4_full', px_metric_scalars(ablation.M4_full));
else
    summary.ablation = struct();
end
summary.limitations = { ...
    '真实视频接口已实现，但本次主验证使用合成等价视频；未获得论文原始视频与加速度计数据。', ...
    'CSP可靠性分布参数、时间窗口长度、异常阈值百分位和部分FISTA细节未完全公开，代码采用了可追溯的实现推断。'};
summary.intermediateData = fullfile(dirs.data, 'intermediate_outputs.mat');
save(fullfile(dirs.data, 'reproduction_results.mat'), 'summary', 'metrics', 'ablation', 'cfg', '-v7.3');
px_write_json(summary, fullfile(outputRoot, 'reproduction_results.json'));
result = summary;
end

function signal = px_raw_signal(phaseDifference, mask)
% 计算不经过时间异常剔除和稀疏重构的基线信号。
matrix = reshape(double(phaseDifference), [], size(phaseDifference, 3));
signal = diff(mean(matrix(mask(:), :), 1)');
end

function metrics = px_nan_metrics()
% 为无加速度计真值的真实视频保留统一结果字段。
metrics.PF = NaN; metrics.FE = NaN; metrics.PER = NaN;
metrics.RMSE = NaN; metrics.PCC = NaN;
metrics.frequency = []; metrics.spectrum = []; metrics.truthSpectrum = [];
end

function scalar = px_metric_scalars(metrics)
% 只把标量指标写入JSON，避免把完整频谱重复写入汇总文件。
scalar.PF_Hz = metrics.PF;
scalar.FE_Hz = metrics.FE;
scalar.PER = metrics.PER;
scalar.RMSE = metrics.RMSE;
scalar.PCC = metrics.PCC;
end
