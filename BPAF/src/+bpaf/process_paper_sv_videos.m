function results = process_paper_sv_videos(cfg, ids, opts)
%PROCESS_PAPER_SV_VIDEOS 流式处理论文规格的 SV1/SV2 视频。
%
% 论文场景没有其他目标。快速验证使用覆盖小球整条水平轨迹的固定横向走廊；
% 高分辨率视频不能安全地一次性装入 phaseCube，因此沿时间在线展开每个
% 像素相位，只保存 ROI 级加权原始信号，再使用同一个 BPAF 时域滤波器。

arguments
    cfg struct = bpaf.default_config()
    ids = {'SV1', 'SV2'}
    opts struct = struct()
end

if ~isfield(opts, 'spatialScale') || isempty(opts.spatialScale)
    opts.spatialScale = 0.5;
end
if ~isfield(opts, 'temporalStride') || isempty(opts.temporalStride)
    opts.temporalStride = 4;
end
if ~isfield(opts, 'tag') || isempty(opts.tag)
    opts.tag = 'fast';
end
if ~isfield(opts, 'measurementRegion') || isempty(opts.measurementRegion)
    % 覆盖小球整个水平运动过程的固定横向走廊，不跟随小球。
    opts.measurementRegion = [1 210 960 120];
end

bpaf.setup_project(cfg);
paperVideoDir = fullfile(cfg.outputDir, 'videos', 'paper_sv');
truthDir = fullfile(cfg.dataDir, 'paper_sv');
figureDir = fullfile(cfg.figureDir, ['paper_sv_processed_' opts.tag]);
resultDir = fullfile(cfg.resultDir, ['paper_sv_' opts.tag]);
if ~isfolder(figureDir), mkdir(figureDir); end
if ~isfolder(resultDir), mkdir(resultDir); end

% 先使用空结构体，首个结果写入时再确定字段集合。
results = struct([]);
for caseIdx = 1:numel(ids)
    id = upper(char(ids{caseIdx}));
    videoPath = fullfile(paperVideoDir, [lower(id), '_paper_960x540_1000fps.avi']);
    truthPath = fullfile(truthDir, [lower(id), '_paper_truth.mat']);
    if ~isfile(videoPath) || ~isfile(truthPath)
        error('process_paper_sv_videos:MissingInput', ...
            '找不到 %s 的论文规格视频或真值。请先运行 generate_paper_sv_videos。', id);
    end

    truthData = load(truthPath, 'truth');
    truth = truthData.truth;
    video = VideoReader(videoPath);
    fs = truth.fs;
    startFrame = round(0.5 * fs) + 1;
    endFrame = min(round(4.5 * fs), floor(video.Duration * fs));
    frameIndices = startFrame:opts.temporalStride:endFrame;
    nFrames = numel(frameIndices);
    effectiveFs = fs / opts.temporalStride;

    firstFrame = read_gray(video, frameIndices(1));
    firstFrame = imresize(firstFrame, opts.spatialScale, 'bilinear');
    [pyr, pind] = buildSCFpyr(firstFrame, cfg.pyramidHeight, cfg.pyramidOrder);
    firstBand = spyrBand(pyr, pind, 1, cfg.orientationBand);
    [bandH, bandW] = size(firstBand);
    rawSignal = zeros(nFrames, 1);
    previousWrapped = [];
    previousUnwrapped = [];
    region = opts.measurementRegion;
    x1 = max(1, floor((region(1)-1) * opts.spatialScale) + 1);
    y1 = max(1, floor((region(2)-1) * opts.spatialScale) + 1);
    x2 = min(bandW, ceil((region(1)+region(3)-1) * opts.spatialScale));
    y2 = min(bandH, ceil((region(2)+region(4)-1) * opts.spatialScale));
    measurementMask = false(bandH, bandW);
    measurementMask(y1:y2, x1:x2) = true;

    fprintf('[BPAF] 流式处理 %s：%d 帧，等效 %.1f Hz，缩放 %.2f，金字塔子带 %dx%d...\n', ...
        id, nFrames, effectiveFs, opts.spatialScale, bandH, bandW);
    for frameIdx = 1:nFrames
        frame = read_gray(video, frameIndices(frameIdx));
        frame = imresize(frame, opts.spatialScale, 'bilinear');
        [pyr, pind] = buildSCFpyr(frame, cfg.pyramidHeight, cfg.pyramidOrder);
        band = spyrBand(pyr, pind, 1, cfg.orientationBand);
        wrapped = angle(band);
        amplitude = abs(band);

        if frameIdx == 1
            unwrapped = wrapped;
        else
            % 与 unwrap(...,[],3) 相同的相邻帧在线展开，避免保存完整 3-D 立方体。
            increment = atan2(sin(wrapped - previousWrapped), ...
                cos(wrapped - previousWrapped));
            unwrapped = previousUnwrapped + increment;
        end
        previousWrapped = wrapped;
        previousUnwrapped = unwrapped;

        localStd = stdfilt(amplitude, true(cfg.localStdWindow));
        score = amplitude ./ max(localStd, 1e-8);
        score = score - min(score, [], 'all');
        score = score ./ max(max(score, [], 'all'), 1e-8);
        score(~measurementMask) = 0;
        rawSignal(frameIdx) = sum(unwrapped(:) .* score(:)) / max(sum(measurementMask(:)), 1);
        if mod(frameIdx, 500) == 0
            fprintf('[BPAF] %s 已完成 %d/%d 帧。\n', id, frameIdx, nFrames);
        end
    end

    truthIndex = frameIndices(frameIndices <= numel(truth.vibrationM));
    truthVibration = truth.vibrationM(truthIndex);
    truthLargeMotion = truth.largeMotionM(truthIndex);
    time = (truthIndex(:) - truthIndex(1)) / fs;
    spec = struct('id', id, 'fs', effectiveFs, 'targetFrequency', truth.targetFrequency, ...
        'analyzeStart', 0.5, 'analyzeDuration', time(end), ...
        'height', round(video.Height*opts.spatialScale), ...
        'width', round(video.Width*opts.spatialScale), 'proxy', false);
    features = struct('rawSignal', rawSignal, 'time', time, 'fs', effectiveFs, ...
        'truthVibration', truthVibration(:), 'truthLargeMotion', truthLargeMotion(:), ...
        'spec', spec, 'measurementMask', measurementMask);

    pve = bpaf.run_method(features, 'PVE', 0, cfg, 'aggregate', false);
    bp = bpaf.run_method(features, 'BP', [10 60], cfg, 'aggregate', false);
    bpafResult = bpaf.run_method(features, 'BPAF', [10 60], cfg, 'aggregate', true);
    truthMetrics = bpaf.evaluate_signal(truthVibration(:), truthVibration(:), effectiveFs, 0);

    result = struct('id', id, 'videoPath', videoPath, 'truthPath', truthPath, ...
        'measurementRegion', sprintf('fixed horizontal corridor [x=%g,y=%g,width=%g,height=%g] in original frame', region), ...
        'measurementRegionRect', region, ...
        'frameRate', effectiveFs, 'originalFrameRate', fs, ...
        'temporalStride', opts.temporalStride, 'spatialScale', opts.spatialScale, ...
        'processedSize', [round(video.Height*opts.spatialScale), round(video.Width*opts.spatialScale)], ...
        'startFrame', startFrame, 'frameCount', nFrames, ...
        'time', time, 'rawSignal', rawSignal, 'truthVibration', truthVibration(:), ...
        'truthLargeMotion', truthLargeMotion(:), 'pve', pve, 'bp', bp, ...
        'bpaf', bpafResult, 'truthMetrics', truthMetrics, ...
        'bandSize', [bandH bandW]);
    if caseIdx == 1
        results = result;
    else
        results(caseIdx) = result;
    end

    save(fullfile(resultDir, [lower(id) '_processed.mat']), 'result', '-v7.3');
    write_metrics(result, resultDir);
    export_visuals(result, video, frameIndices, figureDir);
    fprintf('[BPAF] %s 完成：BPAF PF=%.3f Hz, PER=%.4f, RMSE=%.4f\n', ...
        id, bpafResult.metrics.PF, bpafResult.metrics.PER, bpafResult.metrics.RMSE);
end

save(fullfile(resultDir, 'paper_sv_processed_results.mat'), 'results', '-v7.3');
end

function frame = read_gray(video, index)
frame = read(video, index);
if ndims(frame) == 3
    frame = rgb2gray(frame);
end
frame = im2double(frame);
end

function write_metrics(result, resultDir)
methodNames = {'PVE'; 'BP'; 'BPAF'};
methodResults = {result.pve; result.bp; result.bpaf};
PF = zeros(3,1); PER = zeros(3,1); RMSE = zeros(3,1);
for i = 1:3
    PF(i) = methodResults{i}.metrics.PF;
    PER(i) = methodResults{i}.metrics.PER;
    RMSE(i) = methodResults{i}.metrics.RMSE;
end
T = table(methodNames, PF, PER, RMSE, repmat(result.frameRate,3,1), ...
    'VariableNames', {'Method','PF_Hz','PER','RMSE','FrameRate_Hz'});
writetable(T, fullfile(resultDir, [lower(result.id) '_metrics.csv']));
end

function export_visuals(result, video, frameIndices, figureDir)
set(groot, 'defaultAxesFontName', 'Times New Roman', 'defaultAxesFontSize', 10, ...
    'defaultLineLineWidth', 1.2);
prefix = fullfile(figureDir, lower(result.id));

% 快速处理采用固定横向走廊，覆盖小球整条轨迹，不跟随小球。
frameIds = [frameIndices(1), frameIndices(1+floor((numel(frameIndices)-1)/2)), frameIndices(end)];
fig = figure('Visible','off','Color','w','Position',[100 100 1200 430]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
for i = 1:3
    nexttile; imagesc(read_gray(video, frameIds(i))); axis image off; colormap gray; hold on;
    rectangle('Position',result.measurementRegionRect, 'EdgeColor','r','LineWidth',1.8);
    title(sprintf('%s frame %d\nfixed measurement corridor', result.id, frameIds(i)));
end
exportgraphics(fig, [prefix '_measurement_region.png'], 'Resolution', 200);
save_visible_fig(fig, [prefix '_measurement_region.fig']); close(fig);

fig = figure('Visible','off','Color','w','Position',[100 100 980 520]);
raw = normalize_signal(result.rawSignal);
bpaf = result.bpaf.metrics.normalizedSignal(:);
truth = result.bpaf.metrics.normalizedTruth(:);
plot(result.time, raw, '-', 'Color',[0.55 0.55 0.55]); hold on;
plot(result.time, bpaf, 'k-', 'LineWidth',1.4);
plot(result.time, truth, 'r--', 'LineWidth',1.2);
grid on; xlabel('Time (s)'); ylabel('Normalized signal');
title([result.id ' full-frame measurement: waveform']);
legend({'Raw phase aggregate','BPAF','20 Hz truth'},'Location','best'); xlim([0 result.time(end)]);
exportgraphics(fig, [prefix '_waveform.png'], 'Resolution', 200);
save_visible_fig(fig, [prefix '_waveform.fig']); close(fig);

fig = figure('Visible','off','Color','w','Position',[100 100 980 520]);
plot(result.bpaf.metrics.frequency, result.bpaf.metrics.spectrum, 'k-', 'LineWidth',1.4); hold on;
plot(result.truthMetrics.frequency, result.truthMetrics.spectrum, 'r--', 'LineWidth',1.2);
xline(20, 'b:', '20 Hz');
grid on; xlabel('Frequency (Hz)'); ylabel('Normalized amplitude');
title([result.id ' full-frame measurement: spectrum']);
legend({'BPAF','Truth','Target'},'Location','best'); xlim([0 100]); ylim([0 1.05]);
exportgraphics(fig, [prefix '_spectrum.png'], 'Resolution', 200);
save_visible_fig(fig, [prefix '_spectrum.fig']); close(fig);
end

function y = normalize_signal(x)
x = double(x(:));
y = (x - min(x)) / max(max(x)-min(x), eps);
end

function save_visible_fig(fig, path)
set(fig, 'Visible', 'on');
saveas(fig, path);
set(fig, 'Visible', 'off');
end
