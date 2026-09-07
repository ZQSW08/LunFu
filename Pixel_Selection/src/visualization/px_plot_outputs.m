function px_plot_outputs(video, fs, csp, foreground, spatial, temporal, sparse, truth, ablation, dirs, cfg)
% 保存与论文视觉语义一致的主要结果图和逐阶段过程图。
blue = [31, 119, 180] / 255;
red = [214, 39, 40] / 255;
black = [0.15, 0.15, 0.15];
frameIndex = max(1, round(size(video, 3) / 2));
directionLabel = lower(strtrim(csp.direction));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 700]);
tiledlayout(2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
% 原始输入帧保留灰度语义；响应、掩膜和可靠性结果使用常用parula伪彩色，
% 将输入帧作为RGB灰度真彩色显示，从而避免多坐标轴色图在保存FIG时产生警告。
colormap(fig, parula(256));
nexttile; image(repmat(video(:, :, 1), 1, 1, 3)); axis image off; title('Input frame');
nexttile; imagesc(abs(csp.phaseDifference(:, :, frameIndex))); axis image off; colorbar; title('Phase difference');
nexttile; imagesc(csp.foregroundResponse(:, :, frameIndex)); axis image off; colorbar; title('Weighted response');
nexttile; imagesc(foreground.mask); axis image off; colorbar; title('Foreground C_{max}');
nexttile; imagesc(spatial.mei); axis image off; colorbar; title('MEI');
nexttile; imagesc(spatial.sam); axis image off; colorbar; title('SAM');
nexttile; imagesc(spatial.pse); axis image off; colorbar; title('PSE');
nexttile; imagesc(spatial.confidenceFused, [0 1]); axis image off; colorbar; title('Fused confidence');
px_save_figure_pair(fig, fullfile(dirs.figures, 'matlab_figure_1_process'));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 760]);
tiledlayout(2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
confidenceNames = {'confidenceMei', 'confidenceSam', 'confidencePse', 'confidenceFused'};
confidenceTitles = {'C_M', 'C_S', 'C_P', 'C_f'};
for index = 1:4
    nexttile; imagesc(spatial.(confidenceNames{index}), [0 1]); axis image off; colorbar; title(confidenceTitles{index});
end
nexttile; imagesc(foreground.union); axis image off; colorbar; title('Foreground union');
nexttile; imagesc(foreground.mask); axis image off; colorbar; title('Largest component');
nexttile; imagesc(spatial.reliable); axis image off; colorbar; title('Reliable set R');
nexttile; imagesc(video(:, :, 1)); axis image off; hold on;
contour(spatial.reliable, [0.5 0.5], 'Color', red, 'LineWidth', 0.8); title('R over input'); hold off;
px_save_figure_pair(fig, fullfile(dirs.figures, 'matlab_figure_2_reliability'));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 760]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
time = (0:numel(temporal.signal)-1)' / fs;
nexttile; plot(time, temporal.signal, 'Color', blue, 'LineWidth', 0.8); grid on; xlabel('Time (s)'); ylabel('u(t)'); title('Reliable-pixel signal');
nexttile; plot(time(2:end), temporal.difference, 'Color', blue, 'LineWidth', 0.8); hold on; plot(time(2:end), temporal.refined, 'Color', red, 'LineWidth', 0.8); grid on; xlabel('Time (s)'); ylabel('d(t)'); title('Temporal refinement'); legend('Raw', 'Refined', 'Location', 'best'); hold off;
nexttile; plot(temporal.windowStd, 'Color', blue, 'LineWidth', 0.9); hold on; plot(temporal.windowRange, 'Color', red, 'LineWidth', 0.9); grid on; xlabel('Window'); title('Window statistics'); legend('STD', 'Range', 'Location', 'best'); hold off;
nexttile; plot(temporal.zStd, 'Color', blue, 'LineWidth', 0.8); hold on; plot(temporal.zRange, 'Color', red, 'LineWidth', 0.8); yline(temporal.tau, '--', 'Color', black); yline(-temporal.tau, '--', 'Color', black); grid on; xlabel('Window'); title('Robust Z-scores'); hold off;
nexttile; plot(time(2:end), sparse.reconstructed, 'Color', blue, 'LineWidth', 0.8); grid on; xlabel('Time (s)'); ylabel('Reconstructed'); title('FISTA reconstruction');
nexttile; plot(sparse.fftFrequency, sparse.fftSpectrum, 'Color', blue, 'LineWidth', 0.9); xlim([0 min(50, cfg.sparse.fmax)]); grid on; xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); title(sprintf('FFT peak: %.4f Hz', sparse.peakFrequency));
px_save_figure_pair(fig, fullfile(dirs.figures, 'matlab_figure_3_temporal_frequency'));

% 按用户要求将波形和频谱拆成两个独立文件，并保留可编辑FIG。
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 650]);
timeDifference = (0:numel(temporal.difference)-1)' / fs;
plot(timeDifference, temporal.difference, 'Color', blue, 'LineWidth', 0.8); hold on;
plot(timeDifference, temporal.refined, 'Color', red, 'LineWidth', 0.8);
plot(timeDifference, sparse.reconstructed, 'Color', black, 'LineWidth', 1.0);
grid on; xlabel('Time (s)'); ylabel('Pixel phase difference');
title(sprintf('%s-direction waveform', upper(directionLabel)));
legend('Raw difference', 'Temporal refined', 'FISTA reconstruction', 'Location', 'best');
px_save_figure_pair(fig, fullfile(dirs.figures, ['direction_', directionLabel, '_waveform']));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 650]);
plot(sparse.fftFrequency, sparse.fftSpectrum, 'Color', blue, 'LineWidth', 1.0);
xlim([0 min(50, cfg.sparse.fmax)]); grid on;
xlabel('Frequency (Hz)'); ylabel('Normalized amplitude');
title(sprintf('%s-direction spectrum; peak %.4f Hz', upper(directionLabel), sparse.peakFrequency));
px_save_figure_pair(fig, fullfile(dirs.figures, ['direction_', directionLabel, '_spectrum']));

if ~isempty(truth) && isfield(truth, 'vibration')
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1150 760]);
    tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    truthDifference = diff(double(truth.vibration(:)));
    [truthFrequency, truthSpectrum] = px_normalize_spectrum(truthDifference, truth.fs);
    nexttile; plot(sparse.fftFrequency, sparse.fftSpectrum, 'Color', blue, 'LineWidth', 1.0); hold on; plot(truthFrequency, truthSpectrum, '--', 'Color', red, 'LineWidth', 0.9); xlim([0 50]); grid on; xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); title('M4 spectrum'); legend('Proposed', 'Ground truth', 'Location', 'best'); hold off;
    nexttile; plot(truth.times(2:end), truthDifference, '--', 'Color', red, 'LineWidth', 0.8); hold on; plot(truth.times(2:end), sparse.reconstructed, 'Color', blue, 'LineWidth', 0.8); grid on; xlabel('Time (s)'); title('Reconstructed signal'); legend('Ground truth', 'M4', 'Location', 'best'); hold off;
    nexttile; plot(truth.times, truth.cameraDx, 'Color', blue, 'LineWidth', 0.8); hold on; plot(truth.times, truth.cameraDy, 'Color', red, 'LineWidth', 0.8); grid on; xlabel('Time (s)'); ylabel('Pixels'); title('Synthetic camera motion'); legend('dx', 'dy', 'Location', 'best'); hold off;
    nexttile; px_plot_ablation_axes(ablation, truthDifference, truth.fs, blue, red);
    px_save_figure_pair(fig, fullfile(dirs.figures, 'matlab_figure_4_validation_ablation'));
end

sampleFrames = unique([1, frameIndex, size(video, 3)]);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 650]);
tiledlayout(2, numel(sampleFrames), 'Padding', 'compact', 'TileSpacing', 'compact');
for index = 1:numel(sampleFrames)
    nexttile; imagesc(abs(csp.phaseDifference(:, :, sampleFrames(index)))); axis image off; colorbar; title(sprintf('|dPhi|, frame %d', sampleFrames(index)));
end
for index = 1:numel(sampleFrames)
    nexttile; imagesc(csp.foregroundResponse(:, :, sampleFrames(index))); axis image off; colorbar; title(sprintf('Weighted, frame %d', sampleFrames(index)));
end
px_save_figure_pair(fig, fullfile(dirs.process, 'phase_and_weighted_examples'));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 650]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile; plot(foreground.thresholds, 'Color', blue, 'LineWidth', 0.8); grid on; xlabel('Frame'); title('Adaptive threshold');
nexttile; imagesc(foreground.union); axis image off; colorbar; title('Foreground union');
nexttile; imagesc(foreground.mask); axis image off; colorbar; title('C_{max}');
px_save_figure_pair(fig, fullfile(dirs.process, 'foreground_details'));

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 700]);
tiledlayout(2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
featureNames = {'mei', 'sam', 'pse', 'confidenceFused', 'confidenceMei', 'confidenceSam', 'confidencePse', 'reliable'};
featureTitles = {'MEI', 'SAM', 'PSE', 'C_f', 'C_M', 'C_S', 'C_P', 'Reliable set'};
for index = 1:numel(featureNames)
    nexttile; imagesc(spatial.(featureNames{index})); axis image off; colorbar; title(featureTitles{index});
end
px_save_figure_pair(fig, fullfile(dirs.process, 'spatial_reliability_details'));
end

function px_plot_ablation_axes(ablation, truthDifference, fs, blue, red)
% 重新计算消融序列的频谱，并在同一坐标轴中统一比较。
names = fieldnames(ablation);
hold on;
for index = 1:numel(names)
    metric = ablation.(names{index});
    if isfield(metric, 'rawSignal')
        [frequency, spectrum] = px_normalize_spectrum(metric.rawSignal, fs);
        plot(frequency, spectrum, 'Color', blue * (0.55 + 0.1 * index), 'LineWidth', 0.7);
    end
end
[truthFrequency, truthSpectrum] = px_normalize_spectrum(truthDifference, fs);
plot(truthFrequency, truthSpectrum, '--', 'Color', red, 'LineWidth', 0.8);
xlim([0 50]); grid on; xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); title('Ablation spectra');
if ~isempty(names)
    legend([names(:)', {'Ground truth'}], 'Interpreter', 'none', 'Location', 'best');
end
hold off;
end
