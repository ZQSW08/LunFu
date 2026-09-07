% RUN_PAPER_REPRODUCTION 运行 SPOF 论文的等价合成复现实验。
% 论文真实视频和加速度计数据未公开，本脚本用带真值视频验证算法链、
% 输出论文式波形/频谱/指标，并覆盖论文中列出的主要实验类型。

clear; close all; clc;
rng(20260829, 'twister');
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'src')));

opts.quick = true;
if opts.quick
    duration = 1.5;
    imageSize = 80;
else
    duration = 10;
    imageSize = 240;
end

outFig = fullfile(projectRoot, 'outputs', 'figures');
outProcess = fullfile(projectRoot, 'outputs', 'process');
outVideo = fullfile(projectRoot, 'outputs', 'videos');
if ~exist(outFig, 'dir'), mkdir(outFig); end
if ~exist(outProcess, 'dir'), mkdir(outProcess); end
if ~exist(outVideo, 'dir'), mkdir(outVideo); end

cfg = spof_default_config();
cfg.keepIntermediates = true;
cfg.scaleMmPerPixel = 1;
scenes = {'modal', 'cantilever', 'cable_weak', 'cable_strong', 'bridge_5m', 'bridge_10m'};
methods = {'POF', 'AW-POF', 'MP-POF', 'PNOF', 'SPOF'};
rows = {};
runtimeRows = {};

for s = 1:numel(scenes)
    dataOpts = struct('fs', 100, 'duration', duration, 'height', imageSize, ...
        'width', imageSize, 'noiseStd', 0.004);
    data = spof_generate_synthetic_video(scenes{s}, dataOpts);
    flowTimer = tic;
    sharedFlow = spof_extract_phase_flow(data.video, data.fs, cfg);
    flowSeconds = toc(flowTimer);
    results = cell(numel(methods), 1);
    for m = 1:numel(methods)
        cfg.method = methods{m};
        methodTimer = tic;
        results{m} = spof_measure(data.video, data.fs, data.roi, cfg, sharedFlow);
        runtimeRows(end+1, :) = {scenes{s}, methods{m}, flowSeconds + toc(methodTimer)}; %#ok<SAGROW>
        metric = spof_metrics(data.dx, results{m}.signal.x);
        rows(end+1, :) = {scenes{s}, methods{m}, metric.mae, metric.rmse, metric.pcc}; %#ok<SAGROW>
    end
    cfg.method = 'SPOF';
    plot_comparison(data, results, methods, outFig, scenes{s});
    save_process_figures(data, results{end}, outProcess, scenes{s});
    if strcmp(scenes{s}, 'modal')
        write_demo_video(data, results{end}, outVideo);
    end
end

% 论文 4.1.2 的 alpha 敏感性：固定场景，只改变边缘/平滑先验权重。
alphaList = [0, 0.2, 0.4, 0.6, 0.8, 1];
data = spof_generate_synthetic_video('modal', struct('fs',100,'duration',duration,...
    'height',imageSize,'width',imageSize,'noiseStd',0.004));
sharedFlow = spof_extract_phase_flow(data.video, data.fs, cfg);
alphaMetrics = zeros(numel(alphaList), 3);
for k = 1:numel(alphaList)
    cfg.alpha = alphaList(k); cfg.method = 'SPOF';
    r = spof_measure(data.video, data.fs, data.roi, cfg, sharedFlow);
    alphaMetrics(k,:) = struct_to_row(spof_metrics(data.dx, r.signal.x));
end
cfg.alpha = 0.7;
plot_sensitivity(alphaList, alphaMetrics, outFig, 'alpha_sensitivity');

% 论文 4.1.2 的振幅敏感性：使用同一实现改变合成运动幅度。
ampScale = [0.5, 1, 1.5];
ampMetrics = zeros(numel(ampScale), 3);
for k = 1:numel(ampScale)
    d = spof_generate_synthetic_video('modal', struct('fs',100,'duration',duration,...
        'height',imageSize,'width',imageSize,'noiseStd',0.004));
    d.video = regenerate_scaled_video(d, ampScale(k), dataOpts);
    cfg.method = 'SPOF';
    dFlow = spof_extract_phase_flow(d.video, d.fs, cfg);
    r = spof_measure(d.video, d.fs, d.roi, cfg, dFlow);
    ampMetrics(k,:) = struct_to_row(spof_metrics(d.dx*ampScale(k), r.signal.x));
end
plot_sensitivity(ampScale, ampMetrics, outFig, 'amplitude_sensitivity');

% 论文 Table 4 的 tau/tauC 敏感性：复用一次 GMM 后只改变异常点阈值。
tauList = [0.99, 0.9, 0.8, 0.7, 0.6, 0.5];
thresholdMetrics = zeros(numel(tauList), 4);
cfg.method = 'SPOF'; cfg.alpha = 0.7;
referenceResult = spof_measure(data.video, data.fs, data.roi, cfg, sharedFlow);
for k = 1:numel(tauList)
    cfg.tau = tauList(k); cfg.tauC = 1 - tauList(k);
    [tx, ~] = spof_refine_flow(sharedFlow.vx, referenceResult.confidence, ...
        referenceResult.gmmX.posteriorAbnormal, cfg);
    [ty, ~] = spof_refine_flow(sharedFlow.vy, referenceResult.confidence, ...
        referenceResult.gmmY.posteriorAbnormal, cfg);
    ts = spof_integrate_displacement(tx, ty, data.fs, data.roi, cfg);
    tm = spof_metrics(data.dx, ts.x);
    thresholdMetrics(k,:) = [mean(referenceResult.posteriorAbnormal(:) > cfg.tau & ...
        referenceResult.confidence(:) < cfg.tauC), tm.mae, tm.rmse, tm.pcc];
end
plot_threshold_sensitivity(tauList, thresholdMetrics, outFig);

% 论文 R1-R6 的 ROI 比较：在合成目标内部构造六个有代表性的子区域。
roiMasks = make_roi_masks(data.roi);
roiMetrics = zeros(numel(roiMasks), 3);
for k = 1:numel(roiMasks)
    rs = spof_integrate_displacement(referenceResult.finalFlow.vx, ...
        referenceResult.finalFlow.vy, data.fs, roiMasks{k}, cfg);
    roiMetrics(k,:) = struct_to_row(spof_metrics(data.dx, rs.x));
end
plot_roi_sensitivity(roiMetrics, outFig);

write_table(runtimeRows, fullfile(projectRoot, 'outputs', 'runtime_comparison.csv'), ...
    {'scene','method','seconds'});
write_numeric_table(tauList(:), thresholdMetrics, ...
    fullfile(projectRoot, 'outputs', 'threshold_sensitivity.csv'), ...
    {'tau','abnormal_rate','MAE_Px','RMSE_Px','PCC'});
write_numeric_table((1:size(roiMetrics,1))', roiMetrics, ...
    fullfile(projectRoot, 'outputs', 'roi_sensitivity.csv'), ...
    {'roi','MAE_Px','RMSE_Px','PCC'});
save(fullfile(projectRoot, 'outputs', 'paper_reproduction_results.mat'), ...
    'rows', 'runtimeRows', 'alphaList', 'alphaMetrics', 'ampScale', 'ampMetrics', ...
    'tauList', 'thresholdMetrics', 'roiMetrics');
write_table(rows, fullfile(projectRoot, 'outputs', 'paper_reproduction_metrics.csv'));
fprintf('SPOF 合成复现完成，结果已写入：%s\n', fullfile(projectRoot, 'outputs'));

function row = struct_to_row(m)
row = [m.mae, m.rmse, m.pcc];
end

function plot_comparison(data, results, methods, outDir, scene)
fig = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
for k = 1:numel(methods)
    subplot(3,2,k);
    plot(data.time, data.dx, 'k--', 'LineWidth', 1.1); hold on;
    plot(results{k}.signal.time, results{k}.signal.x, 'r', 'LineWidth', 0.8);
    grid on; xlabel('Time (s)'); ylabel('Displacement (Px)');
    title(methods{k}, 'Interpreter','none'); legend('Ground truth','Camera','Location','best');
end
sgtitle(['SPOF equivalent reproduction: ', scene], 'Interpreter','none');
saveas(fig, fullfile(outDir, [scene, '_waveforms.png'])); close(fig);
end

function save_process_figures(data, result, outDir, scene)
frameIndex = min(10, size(data.video,3));
fig = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
subplot(2,3,1); imagesc(data.video(:,:,frameIndex)); axis image off; title('Input frame'); colormap gray;
subplot(2,3,2); imagesc(abs(result.flow.responses{1}(:,:,frameIndex))); axis image off; title('Gabor amplitude'); colorbar;
subplot(2,3,3); imagesc(result.flow.phases{1}(:,:,frameIndex)); axis image off; title('Unwrapped phase'); colorbar;
subplot(2,3,4); imagesc(result.confidence(:,:,frameIndex)); axis image off; title('Confidence C'); colorbar;
subplot(2,3,5); imagesc(result.abnormalMask(:,:,frameIndex)); axis image off; title('Abnormal mask'); colorbar;
subplot(2,3,6); imagesc(result.finalFlow.vx(:,:,frameIndex)); axis image off; title('Refined v_x (Px/s)'); colorbar;
sgtitle(['SPOF process outputs: ', scene], 'Interpreter','none');
saveas(fig, fullfile(outDir, [scene, '_process.png'])); close(fig);
end

function plot_sensitivity(x, metrics, outDir, name)
fig = figure('Visible','off','Color','w','Position',[100 100 900 600]);
yyaxis left; plot(x, metrics(:,1), '-o', 'LineWidth', 1.3); hold on;
plot(x, metrics(:,2), '-s', 'LineWidth', 1.3); ylabel('Error (Px)');
yyaxis right; plot(x, metrics(:,3), '-^', 'LineWidth', 1.3); ylabel('PCC');
grid on; xlabel(strrep(name, '_', ' ')); legend('MAE','RMSE','PCC','Location','best');
title(['SPOF sensitivity: ', strrep(name, '_', ' ')]); saveas(fig, fullfile(outDir,[name,'.png'])); close(fig);
end

function video = regenerate_scaled_video(data, scale, opts)
base = data.baseImage; [h,w] = size(base); [x,y] = meshgrid(1:w,1:h);
video = zeros(h,w,numel(data.time));
for k=1:numel(data.time)
    frame = interp2(x,y,base,x-scale*data.dx(k),y-scale*data.dy(k),'linear',0.2);
    video(:,:,k) = min(max(frame + opts.noiseStd*randn(h,w),0),1);
end
end

function write_demo_video(data, result, outDir)
try
    writer = VideoWriter(fullfile(outDir, 'modal_spof_demo.mp4'), 'MPEG-4');
    writer.FrameRate = data.fs; open(writer);
    for k=1:size(data.video,3)
        frame = repmat(data.video(:,:,k),1,1,3);
        shift = round(result.signal.x(k));
        if shift ~= 0
            frame = circshift(frame,[0,shift,0]);
        end
        writeVideo(writer, frame);
    end
    close(writer);
catch err
    warning('SPOF:VideoWrite', '演示视频写入失败：%s', err.message);
end
end

function plot_threshold_sensitivity(tauList, metrics, outDir)
fig = figure('Visible','off','Color','w','Position',[100 100 900 600]);
yyaxis left; plot(tauList, metrics(:,2), '-o', 'LineWidth', 1.3); hold on;
plot(tauList, metrics(:,3), '-s', 'LineWidth', 1.3); ylabel('Error (Px)');
yyaxis right; plot(tauList, metrics(:,4), '-^', 'LineWidth', 1.3); ylabel('PCC');
grid on; xlabel('tau (tauC=1-tau)'); legend('MAE','RMSE','PCC','Location','best');
title('SPOF threshold sensitivity'); saveas(fig, fullfile(outDir,'threshold_sensitivity.png')); close(fig);
end

function masks = make_roi_masks(fullRoi)
[y, x] = find(fullRoi); x1=min(x); x2=max(x); y1=min(y); y2=max(y);
masks = cell(6,1);
masks{1} = fullRoi & make_rect(size(fullRoi), x1, y1, x2, y1+round((y2-y1)/3));
masks{2} = fullRoi & make_rect(size(fullRoi), x1, y1, x1+round((x2-x1)/3), y2);
masks{3} = fullRoi & make_rect(size(fullRoi), x1+round((x2-x1)/3), y1, x1+round(2*(x2-x1)/3), y2);
masks{4} = fullRoi & make_rect(size(fullRoi), x1, y2-round((y2-y1)/3), x2, y2);
masks{5} = fullRoi & make_rect(size(fullRoi), x1+round((x2-x1)/3), y1+round((y2-y1)/3), x1+round(2*(x2-x1)/3), y1+round(2*(y2-y1)/3));
masks{6} = fullRoi & make_rect(size(fullRoi), x2-round((x2-x1)/3), y1, x2, y2);
end

function mask = make_rect(sz, x1, y1, x2, y2)
mask = false(sz); mask(max(1,y1):min(sz(1),y2), max(1,x1):min(sz(2),x2)) = true;
end

function plot_roi_sensitivity(metrics, outDir)
fig = figure('Visible','off','Color','w','Position',[100 100 900 600]);
bar(metrics(:,1:2)); grid on; xlabel('ROI'); ylabel('Error (Px)');
legend('MAE','RMSE','Location','best'); title('SPOF ROI sensitivity');
saveas(fig, fullfile(outDir,'roi_sensitivity.png')); close(fig);
end

function write_table(rows, filename, header)
if nargin < 3, header = {'scene','method','MAE_Px','RMSE_Px','PCC'}; end
fid = fopen(filename, 'w');
fprintf(fid, '%s\n', strjoin(header, ','));
for k=1:size(rows,1)
    if size(rows,2) == 3
        fprintf(fid, '%s,%s,%.8g\n', rows{k,1}, rows{k,2}, rows{k,3});
    else
        fprintf(fid, '%s,%s,%.8g,%.8g,%.8g\n', rows{k,1}, rows{k,2}, rows{k,3}, rows{k,4}, rows{k,5});
    end
end
fclose(fid);
end

function write_numeric_table(x, values, filename, header)
fid = fopen(filename, 'w'); fprintf(fid, '%s\n', strjoin(header, ','));
for k=1:numel(x)
    fprintf(fid, '%.8g', x(k));
    fprintf(fid, ',%.8g', values(k,:)); fprintf(fid, '\n');
end
fclose(fid);
end
