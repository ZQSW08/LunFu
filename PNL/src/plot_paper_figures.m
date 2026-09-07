function plot_paper_figures(results, cleanImages)
%PLOT_PAPER_FIGURES 生成与论文 Fig. 1-10、18-19 信息结构一致的图。
%   论文 Fig. 11-17 属于真实钢架实验；因作者未共享数据，不生成伪造实验图。

cfg = results.config;
set(groot, 'defaultAxesFontName', 'Times New Roman');
set(groot, 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 9);
colors.generic = [0.9290 0.6940 0.1250];
colors.klt = [0.0000 0.4470 0.7410];
colors.pofcm = [0.4660 0.6740 0.1880];
colors.proposed = [0.8500 0.2000 0.1000];
colors.truth = [0.10 0.10 0.10];

fig01_workflow(cfg, colors);
fig02_local_coordinate(cfg, colors);
fig03_filter_responses(cfg);
fig04_phase_gradient_profiles(cfg);
fig05_simulation_setup(cfg, cleanImages, results.truth);
fig06_gradient_time(results, colors);
fig07_gradient_distribution(results, colors);
fig08_motion(results, colors);
fig09_algorithm_comparison(results, colors);
fig10_noise(results, cleanImages, colors);
fig18_amplitude(results, colors);
fig19_amplitude_error(results, colors);
write_experiment_data_notice(cfg);
end

function fig01_workflow(cfg, colors)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 300]);
ax = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off');
labels = {'Stereo images', 'Complex Gabor', 'Phase gradient\newline + PNL', ...
    'POF Eq. (8)-(10)', 'Stereo triangulation', 'Local 3D / ODS'};
for k = 1:numel(labels)
    x = 0.03 + (k - 1) * 0.16;
    rectangle(ax, 'Position', [x 0.36 0.12 0.28], 'Curvature', 0.03, ...
        'FaceColor', [0.94 0.94 0.94], 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 1);
    text(ax, x + 0.06, 0.50, labels{k}, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Interpreter', 'tex', 'FontSize', 11);
    if k < numel(labels)
        annotation(fig, 'arrow', [x + 0.125 x + 0.155], [0.50 0.50], 'Color', colors.proposed, 'LineWidth', 1.2);
    end
end
title(ax, 'Workflow of the proposed 3D vibration measurement', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_01_workflow.png'));
end

function fig02_local_coordinate(cfg, colors)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 720 560]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); axis(ax, 'equal'); view(ax, 35, 22);
quiver3(ax, 0, 0, 0, 4, 0, 0, 0, 'Color', colors.proposed, 'LineWidth', 1.8, 'MaxHeadSize', .5);
quiver3(ax, 0, 0, 0, 0, 4, 0, 0, 'Color', colors.klt, 'LineWidth', 1.8, 'MaxHeadSize', .5);
quiver3(ax, 0, 0, 0, 0, 0, 4, 0, 'Color', colors.pofcm, 'LineWidth', 1.8, 'MaxHeadSize', .5);
plot3(ax, [-3 3 3 -3 -3], [-2 -2 2 2 -2], zeros(1, 5), 'k-', 'LineWidth', 1.2);
text(ax, 4.2, 0, 0, 'x: line direction'); text(ax, 0, 4.2, 0, 'y'); text(ax, 0, 0, 4.2, 'z: normal');
xlabel(ax, 'Local x'); ylabel(ax, 'Local y'); zlabel(ax, 'Local z');
title(ax, 'Local coordinate system defined by the crossline marker', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_02_local_coordinate.png'));
end

function fig03_filter_responses(cfg)
[texture, ~, ~] = make_crossline_texture(cfg);
filters = {cfg.filter.figure3, struct('f', 1 / 8, 'sigmaA', 16, 'sigmaR', 16)};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 560]);
for k = 1:2
    f = filters{k};
    g = complex_gabor_kernel(f.f, f.sigmaA, f.sigmaR, 0);
    resp = local_filter(texture, g);
    subplot(2, 4, (k - 1) * 4 + 1); imagesc(texture); axis image off; colormap gray;
    title(sprintf('(%c) Crossline marker', 'a' + k - 1), 'FontWeight', 'normal');
    subplot(2, 4, (k - 1) * 4 + 2); imagesc(log(abs(fftshift(fft2(g, 128, 128))) + 1e-5)); axis image off; colormap gray;
    title(sprintf('Frequency domain: f=1/%g', 1 / f.f), 'FontWeight', 'normal');
    subplot(2, 4, (k - 1) * 4 + 3); imagesc(real(g)); axis image off; colormap gray;
    title(sprintf('Spatial domain: sigma=%g', f.sigmaA), 'FontWeight', 'normal');
    subplot(2, 4, (k - 1) * 4 + 4); imagesc(angle(resp)); axis image off; colormap gray;
    title('Local phase map', 'FontWeight', 'normal');
end
sgtitle('Complex Gabor filters and their responses', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_03_filter_responses.png'));
end

function fig04_phase_gradient_profiles(cfg)
[texture, ~, ~] = make_crossline_texture(cfg);
filters = {cfg.filter.figure3, cfg.filter.geometry};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 920 390]);
for k = 1:2
    f = filters{k};
    g = complex_gabor_kernel(f.f, f.sigmaA, f.sigmaR, 0);
    phase = angle(local_filter(texture, g));
    row = round(size(phase, 1) / 2);
    profile = unwrap(phase(row, :));
    gradientProfile = gradient(profile);
    subplot(1, 2, k); plot(gradientProfile, 'Color', [0.10 0.35 0.75], 'LineWidth', 1.2); grid on;
    xlabel('Pixel'); ylabel('Phase gradient');
    title(sprintf('%s filter', ternary(k == 1, 'Generic', 'Geometry-guided')), 'FontWeight', 'normal');
end
sgtitle('Comparison of one-dimensional phase gradients', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_04_phase_gradient_profiles.png'));
end

function fig05_simulation_setup(cfg, cleanImages, truth)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 450]);
subplot(1, 3, 1); hold on; grid on; view(35, 20); axis equal;
plot3(truth.center3d(1, :), truth.center3d(2, :), truth.center3d(3, :), 'k-', 'LineWidth', 1.1);
scatter3(truth.center3d(1, 1), truth.center3d(2, 1), truth.center3d(3, 1), 45, 'r', 'filled');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)'); title('3D motion trajectory', 'FontWeight', 'normal');
subplot(1, 3, 2); imagesc(cleanImages{1}(:, :, 1)); axis image off; colormap gray; title('Image 1 (simulated)', 'FontWeight', 'normal');
subplot(1, 3, 3); imagesc(cleanImages{2}(:, :, 1)); axis image off; colormap gray; title('Image 2 (simulated)', 'FontWeight', 'normal');
sgtitle(sprintf('Simulation setup: %d fps, baseline=%g mm, sigma=0-20 px', cfg.fps, cfg.baseline), 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_05_simulation_setup.png'));
end

function fig06_gradient_time(results, colors)
cfg = results.config;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 620]);
names = {'generic', 'geometry'};
for m = 1:2
    e1 = results.core.(names{m}).camera(1);
    e2 = results.core.(names{m}).camera(2);
    for c = 1:2
        for d = 1:2
            idx = (m - 1) * 4 + (c - 1) * 2 + d;
            subplot(2, 4, idx);
            data = squeeze(e1.meanGradientTime(d, :, 1));
            if c == 2, data = squeeze(e2.meanGradientTime(d, :, 1)); end
            plot(1:numel(data), data, 'Color', pick_method_color(m, colors), 'LineWidth', 0.9); grid on;
            xlabel('Frame'); ylabel('Phase Gradient');
            title(sprintf('%s Cam%d %s', method_label(m), c, ternary(d == 1, 'u', 'v')), 'FontWeight', 'normal');
        end
    end
end
sgtitle('Temporal evolution of the mean spatial phase gradients', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_06_phase_gradient_time.png'));
end

function fig07_gradient_distribution(results, colors)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 930 650]);
for m = 1:2
    e = results.core.(ternary(m == 1, 'generic', 'geometry')).camera(2);
    subplot(2, 2, m); data = squeeze(e.meanGradientTime(2, :, 1));
    plot(1:numel(data), data, 'Color', pick_method_color(m, colors), 'LineWidth', 1); grid on;
    xlabel('Frame'); ylabel('Phase Gradient'); title(sprintf('(%c) %s, Cam 2 v', 'a' + m - 1, method_label(m)), 'FontWeight', 'normal');
    subplot(2, 2, m + 2); hold on; grid on;
    edges = e.gradientDistribution.edges; centers = (edges(1:end-1) + edges(2:end)) / 2;
    pre = squeeze(e.gradientDistribution.pre(2, :, 2)); post = squeeze(e.gradientDistribution.post(2, :, 2));
    plot(centers, pre / max(sum(pre), 1), 'b-', 'LineWidth', 1.1, 'DisplayName', 'Before Z motion');
    plot(centers, post / max(sum(post), 1), 'r-', 'LineWidth', 1.1, 'DisplayName', 'After Z motion');
    xlabel('Phase Gradient'); ylabel('Density (normalized)'); title(sprintf('(%c) Probability density', 'c' + m - 1), 'FontWeight', 'normal');
    xlim([-0.08 0.08]);
    if m == 1, legend('Location', 'best'); end
end
sgtitle('Comparison of phase gradients before and after Z-axis motion', 'FontWeight', 'normal');
save_figure(fig, fullfile(results.config.output.figures, 'fig_07_gradient_distributions.png'));
end

function fig08_motion(results, colors)
cfg = results.config; truth = results.truth.displacement3d; axisNames = 'XYZ'; fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1120 680]);
methods = {'generic', 'geometry'}; labels = {'Generic Filter', 'Proposed Method'};
for col = 1:2
    result = results.core.(methods{col}).xyz;
    for axisId = 1:3
        subplot(3, 2, (axisId - 1) * 2 + col); hold on; grid on;
        plot(truth(axisId, :), 'k:', 'LineWidth', 1.0, 'DisplayName', 'Ground Truth');
        plot(result(axisId, :), 'Color', pick_method_color(col, colors), 'LineWidth', 1.0, 'DisplayName', labels{col});
        metric = results.core.(methods{col}).metrics(axisId);
        title(sprintf('Cross Correlation: %.4f; MAE: %.4f', metric.corr, metric.mae), 'FontWeight', 'normal');
        ylabel(sprintf('%s (mm)', axisNames(axisId))); if axisId == 3, xlabel('Frame'); end
        if axisId == 1 && col == 1, legend('Location', 'best'); end
    end
end
save_figure(fig, fullfile(cfg.output.figures, 'fig_08_estimated_motion.png'));
end

function fig09_algorithm_comparison(results, colors)
truth = results.truth.displacement3d; axisNames = 'XYZ'; fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1120 700]);
names = {'klt', 'pofcm', 'generic', 'geometry'}; labels = {'KLT', 'POF-CM', 'Generic Filter', 'Proposed Method'};
cols = [colors.klt; colors.pofcm; colors.generic; colors.proposed];
for axisId = 1:3
    for panel = 1:2
        subplot(3, 2, (axisId - 1) * 2 + panel); hold on; grid on;
        if panel == 1, index = 1:size(truth, 2); else, index = 150:min(250, size(truth, 2)); end
        plot(index, truth(axisId, index), 'k:', 'LineWidth', 1, 'DisplayName', 'Ground Truth');
        for m = 1:numel(names)
            plot(index, results.core.(names{m}).xyz(axisId, index), 'Color', cols(m, :), 'LineWidth', .9, 'DisplayName', labels{m});
        end
        ylabel(sprintf('%s (mm)', axisNames(axisId))); if axisId == 3, xlabel('Frame'); end
        if axisId == 1 && panel == 1, legend('Location', 'best'); end
        if panel == 2, title('Zoomed comparison', 'FontWeight', 'normal'); end
    end
end
sgtitle('Performance comparison with KLT and POF-CM references', 'FontWeight', 'normal');
save_figure(fig, fullfile(results.config.output.figures, 'fig_09_algorithm_comparison.png'));
end

function fig10_noise(results, cleanImages, colors)
cfg = results.config; axisNames = 'XYZ'; fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 700]);
tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile([2 1]); imagesc(noise_montage(cleanImages{1}(:, :, 1), cfg.noiseLevels)); axis image off; colormap gray;
title('Simulated images with noise', 'FontWeight', 'normal');
names = {'generic', 'klt', 'pofcm', 'geometry'}; labels = {'Generic Filter', 'KLT', 'POF-CM', 'Proposed Method'};
cols = [colors.generic; colors.klt; colors.pofcm; colors.proposed];
for axisId = 1:3
    nexttile; hold on; grid on;
    for m = 1:4
        y = arrayfun(@(x) x.(names{m}).metrics(axisId).corr, results.noise);
        plot(cfg.noiseLevels, y, '-o', 'Color', cols(m, :), 'LineWidth', 1, 'MarkerSize', 3, 'DisplayName', labels{m});
    end
    xlabel('Gaussian noise level (sigma)'); ylabel(sprintf('%s correlation', axisNames(axisId)));
    if axisId == 1, legend('Location', 'southwest'); end
end
for axisId = 1:3
    nexttile; hold on; grid on;
    for m = 1:4
        y = arrayfun(@(x) x.(names{m}).metrics(axisId).mae, results.noise);
        plot(cfg.noiseLevels, y, '-o', 'Color', cols(m, :), 'LineWidth', 1, 'MarkerSize', 3, 'DisplayName', labels{m});
    end
    xlabel('Gaussian noise level (sigma)'); ylabel(sprintf('%s MAE (mm)', axisNames(axisId)));
end
save_figure(fig, fullfile(cfg.output.figures, 'fig_10_noise_robustness.png'));
end

function fig18_amplitude(results, colors)
cfg = results.config; fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 700]);
amp = cfg.amplitudeLevels; rmsTrue = [results.amplitude.rms];
subplot(2, 2, 1); loglog(amp, rmsTrue, 'k-o', 'LineWidth', 1); grid on; xlabel('Input amplitude (mm)'); ylabel('RMS (mm)'); title('(a) Input amplitude', 'FontWeight', 'normal');
subplot(2, 2, 2); hold on; grid on;
for k = 1:numel(results.amplitude)
    plot(results.amplitude(k).metrics(3).corr, rmsTrue(k), 'o', 'Color', colors.proposed, 'MarkerFaceColor', colors.proposed);
end
xlabel('Z correlation'); ylabel('Input RMS (mm)'); title('(b) Synthetic 30 Hz amplitude sweep', 'FontWeight', 'normal');
subplot(2, 2, [3 4]); hold on; grid on;
for k = 1:numel(results.amplitude)
    t = (0:size(results.amplitude(k).xyz, 2) - 1) / cfg.fps;
    plot(t + (k - 1), results.amplitude(k).xyz(3, :), 'Color', colors.proposed, 'LineWidth', .8);
end
xlabel('Concatenated segment time (s)'); ylabel('Estimated Z displacement (mm)');
title('(c) Processed image-based displacement segments', 'FontWeight', 'normal');
sgtitle('Time-domain displacement responses across synthetic vibration amplitudes', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_18_amplitude_response.png'));
end

function fig19_amplitude_error(results, colors)
cfg = results.config; amp = cfg.amplitudeLevels;
rmse = arrayfun(@(x) x.metrics(3).rmse, results.amplitude); snr = arrayfun(@(x) x.metrics(3).snr, results.amplitude);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 430]);
subplot(1, 2, 1); semilogx(amp, snr, '-o', 'Color', colors.proposed, 'LineWidth', 1.2); grid on; xlabel('Input amplitude (mm)'); ylabel('SNR (dB)'); title('(a) SNR', 'FontWeight', 'normal');
subplot(1, 2, 2); loglog(amp, rmse, '-o', 'Color', colors.proposed, 'LineWidth', 1.2); grid on; xlabel('Input amplitude (mm)'); ylabel('RMSE (mm)'); title('(b) RMSE', 'FontWeight', 'normal');
sgtitle('Measurement error comparison across synthetic vibration amplitudes', 'FontWeight', 'normal');
save_figure(fig, fullfile(cfg.output.figures, 'fig_19_amplitude_error.png'));
end

function write_experiment_data_notice(cfg)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 430]);
axis off; text(.05, .78, 'Figs. 11-17: real experimental data not available', 'FontSize', 17, 'FontWeight', 'bold');
text(.05, .60, {'The paper states: Data availability - the authors do not have permission to share data.', ...
    'Therefore no steel-frame, LDV, accelerometer, illumination, or 3D-DIC result is fabricated here.', ...
    'The data interface and ODS extraction function are preserved in data/README.md and src/compute_ods.m.'}, ...
    'FontSize', 12, 'VerticalAlignment', 'top');
save_figure(fig, fullfile(cfg.output.process, 'experimental_data_unavailable.png'));
end

function response = local_filter(image, kernel)
[H, W] = size(image); K = zeros(H, W, 'like', kernel); K(1:size(kernel, 1), 1:size(kernel, 2)) = kernel;
K = circshift(K, -floor([size(kernel, 1), size(kernel, 2)] / 2));
response = ifft2(fft2(image) .* fft2(K));
end

function montage = noise_montage(image, levels)
[H, W] = size(image); montage = zeros(2 * H, 3 * W);
for k = 1:numel(levels)
    row = floor((k - 1) / 3); col = mod(k - 1, 3);
    frame = min(max(image + levels(k) / 255 * randn(size(image)), 0), 1);
    montage(row * H + (1:H), col * W + (1:W)) = frame;
end
end

function save_figure(fig, path)
set(fig, 'PaperPositionMode', 'auto');
try
    exportgraphics(fig, path, 'Resolution', 300);
catch
    saveas(fig, path);
end
[folder, name] = fileparts(path);
figPath = fullfile(folder, [name '.fig']);
oldVisible = fig.Visible;
fig.Visible = 'on';
savefig(fig, figPath);
fig.Visible = oldVisible;
close(fig);
end

function out = ternary(condition, a, b)
if condition, out = a; else, out = b; end
end

function label = method_label(k)
label = ternary(k == 1, 'Generic', 'Proposed');
end

function c = pick_method_color(k, colors)
c = ternary(k == 1, colors.generic, colors.proposed);
end
