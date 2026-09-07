function results = run_pnl_reproduction(mode)
%RUN_PNL_REPRODUCTION 运行论文 PNL 复现的完整软件流程。
%   包含：耦合 3D 仿真、通用/几何匹配 Gabor 对比、噪声扫描、
%   POF-CM 风格置信度对照，以及指数增幅振动的噪声底分析。
%   真实钢架实验因论文数据不可共享，见 data/README.md。

if nargin == 0
    mode = 'demo';
end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
cfg = pnl_config(mode);
ensure_dirs(cfg);
rng(cfg.seed, 'twister');

fprintf('PNL reproduction: mode=%s, ROI=%dx%d, frames=%d\n', ...
    cfg.mode, cfg.roiSize(1), cfg.roiSize(2), cfg.nFrames);

% 1) 论文 Fig. 5-8：耦合运动的无噪声核心仿真。
[cleanImages, truth] = simulate_stereo_sequence(cfg, 0);
methods = {'generic', 'geometry'};
core = struct();
for im = 1:numel(methods)
    name = methods{im};
    fcfg = cfg.filter.(name);
    core.(name) = struct();
    uv = zeros(2, cfg.nFrames, 2);
    for cam = 1:2
        fprintf('  core %s / camera %d\n', name, cam);
        core.(name).camera(cam) = phase_flow_sequence(cleanImages{cam}, cfg, fcfg, false);
        uv(:, :, cam) = truth.uv(:, 1, cam) + core.(name).camera(cam).cumulativeUV;
    end
    xyz = local_coordinates(triangulate_stereo_sequence(cfg, uv), cfg);
    core.(name).xyz = xyz;
    core.(name).uv = uv;
    core.(name).metrics = axis_metrics(xyz, truth.displacement3d);
end

% 论文 Fig. 9 的两个参考方法：POF-CM 与 KLT。
core.pofcm = struct();
uv = zeros(2, cfg.nFrames, 2);
for cam = 1:2
    core.pofcm.camera(cam) = phase_flow_sequence(cleanImages{cam}, cfg, cfg.filter.geometry, true);
    uv(:, :, cam) = truth.uv(:, 1, cam) + core.pofcm.camera(cam).cumulativeUV;
end
core.pofcm.xyz = local_coordinates(triangulate_stereo_sequence(cfg, uv), cfg);
core.pofcm.uv = uv;
core.pofcm.metrics = axis_metrics(core.pofcm.xyz, truth.displacement3d);

core.klt = struct();
uv = zeros(2, cfg.nFrames, 2);
for cam = 1:2
    core.klt.camera(cam) = estimate_klt_sequence(cleanImages{cam}, cfg);
    uv(:, :, cam) = truth.uv(:, 1, cam) + core.klt.camera(cam).cumulativeUV;
end
core.klt.xyz = local_coordinates(triangulate_stereo_sequence(cfg, uv), cfg);
core.klt.uv = uv;
core.klt.metrics = axis_metrics(core.klt.xyz, truth.displacement3d);

% 2) 论文 Fig. 10：高斯噪声扫描，加入 POF-CM 风格加权作为参考方法。
noise = struct();
for ni = 1:numel(cfg.noiseLevels)
    sigma = cfg.noiseLevels(ni);
    fprintf('  noise sigma=%g\n', sigma);
    noisy = add_sequence_noise(cleanImages, sigma);
    for im = 1:numel(methods)
        name = methods{im};
        [noise(ni).(name).metrics, noise(ni).(name).pnl] = ...
            estimate_stereo_case(noisy, cfg, cfg.filter.(name), false, truth);
    end
    [noise(ni).klt.metrics, noise(ni).klt.pnl] = estimate_klt_stereo_case(noisy, cfg, truth);
    [noise(ni).pofcm.metrics, noise(ni).pofcm.pnl] = ...
        estimate_stereo_case(noisy, cfg, cfg.filter.geometry, true, truth);
end

% 3) 论文 Fig. 18-19：指数增幅 30 Hz 合成振动与噪声底分析。
amplitude = struct();
for ai = 1:numel(cfg.amplitudeLevels)
    acfg = cfg;
    acfg.nFrames = round(cfg.amplitudeDuration * cfg.fps);
    acfg.motion.type = 'amplitude';
    acfg.motion.amplitude = cfg.amplitudeLevels(ai);
    acfg.motion.frequency = 30;
    amotion = make_amplitude_motion(acfg);
    [aImages, aTruth] = simulate_stereo_sequence(acfg, 4, amotion);
    [amplitude(ai).metrics, amplitude(ai).pnl, amplitude(ai).xyz] = ...
        estimate_stereo_case(aImages, acfg, acfg.filter.geometry, false, aTruth);
    amplitude(ai).rms = sqrt(mean(aTruth.displacement3d(3, :) .^ 2));
end

results = struct();
results.config = cfg;
results.truth = truth;
results.core = core;
results.noise = noise;
results.amplitude = amplitude;
results.paperReported = paper_reported_values();
plot_paper_figures(results, cleanImages);
write_noise_csv(results);
if cfg.writeVideos
    results.videoPaths = write_simulation_videos(cfg);
end
save(cfg.output.results, 'results', '-v7.3');
fprintf('Results written to %s\n', cfg.output.results);
end

function [metrics, pnl, xyz] = estimate_stereo_case(images, cfg, fcfg, confidence, truth)
uv = zeros(2, size(images{1}, 3), 2);
pnl = zeros(1, 2);
for cam = 1:2
    e = phase_flow_sequence(images{cam}, cfg, fcfg, confidence);
    uv(:, :, cam) = truth.uv(:, 1, cam) + e.cumulativeUV;
    pnl(cam) = e.pnlScalar;
end
xyz = local_coordinates(triangulate_stereo_sequence(cfg, uv), cfg);
metrics = axis_metrics(xyz, truth.displacement3d);
end

function [metrics, pnl] = estimate_klt_stereo_case(images, cfg, truth)
uv = zeros(2, size(images{1}, 3), 2);
for cam = 1:2
    e = estimate_klt_sequence(images{cam}, cfg);
    uv(:, :, cam) = truth.uv(:, 1, cam) + e.cumulativeUV;
end
xyz = local_coordinates(triangulate_stereo_sequence(cfg, uv), cfg);
metrics = axis_metrics(xyz, truth.displacement3d);
pnl = [NaN, NaN];
end

function out = axis_metrics(xyz, truth)
out = repmat(struct('corr', NaN, 'mae', NaN, 'rmse', NaN, 'snr', NaN), 3, 1);
for k = 1:3
    out(k) = compute_metrics(xyz(k, :), truth(k, :));
end
end

function imagesOut = add_sequence_noise(imagesIn, sigma)
imagesOut = cell(size(imagesIn));
for cam = 1:numel(imagesIn)
    imagesOut{cam} = min(max(imagesIn{cam} + single(sigma / 255 * randn(size(imagesIn{cam}))), 0), 1);
end
end

function motion = make_amplitude_motion(cfg)
t = (0:cfg.nFrames - 1) / cfg.fps;
motion = zeros(3, cfg.nFrames);
motion(3, :) = cfg.motion.amplitude * exp(0.35 * t) .* sin(2 * pi * cfg.motion.frequency * t);
end

function p = paper_reported_values()
% 论文表格中的参考值仅用于结果记录，不参与本地仿真结果计算。
p.genericZcorr = 0.9247;
p.genericZmae = 0.1333;
p.geometryZmae = 0.0281;
p.experimentAngles = [0, 40, 90];
p.experimentCorr = [0.9988, 0.9971, 0.9995];
p.experimentMAE = [0.0101, 0.0163, 0.0070];
p.noiseFloorRMSmm = 0.0058;
end

function ensure_dirs(cfg)
dirs = {cfg.output.figures, cfg.output.process, cfg.output.videos};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir')
        mkdir(dirs{k});
    end
end
end

function make_figures(results)
cfg = results.config;
truth = results.truth;

% 核心 3D 结果与论文 Fig. 8 对照。
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 760]);
names = {'X', 'Y', 'Z'};
for k = 1:3
    subplot(3, 1, k);
    plot(truth.displacement3d(k, :), 'k-', 'LineWidth', 1.1); hold on;
    plot(results.core.generic.xyz(k, :), 'Color', [0.85 0.25 0.15]);
    plot(results.core.geometry.xyz(k, :), 'Color', [0.05 0.35 0.80]);
    ylabel([names{k} ' (mm)']); grid on;
    if k == 1
        legend('Ground truth', 'Generic Gabor', 'Geometry-guided', 'Location', 'best');
    end
end
xlabel('Frame');
saveas(fig, fullfile(cfg.output.figures, 'fig_core_3d_motion.png'));
close(fig);

% PNL 空间图，保留论文 Fig. 6-7 的过程证据；用对数色标避免少数
% 低梯度像素把纹理区域压扁。数值原图仍保存在 MAT 结果中。
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 420]);
subplot(1, 2, 1); imagesc(log10(1 + min(results.core.generic.camera(1).pnlMap, 1e3))); axis image; colorbar;
title('Generic filter: log(1+PNL)'); xlabel('u'); ylabel('v');
subplot(1, 2, 2); imagesc(log10(1 + min(results.core.geometry.camera(1).pnlMap, 1e3))); axis image; colorbar;
title('Geometry-guided filter: log(1+PNL)'); xlabel('u'); ylabel('v');
saveas(fig, fullfile(cfg.output.process, 'process_pnl_maps.png'));
close(fig);

% 噪声扫描：Z 轴 MAE 与相关系数。
sigmas = cfg.noiseLevels;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 700]);
subplot(2, 1, 1); hold on; grid on;
for name = {'generic', 'geometry', 'pofcm'}
    y = arrayfun(@(x) x.(name{1}).metrics(3).corr, results.noise);
    plot(sigmas, y, '-o', 'LineWidth', 1.2, 'DisplayName', name{1});
end
ylabel('Z correlation'); legend('Location', 'southwest');
subplot(2, 1, 2); hold on; grid on;
for name = {'generic', 'geometry', 'pofcm'}
    y = arrayfun(@(x) x.(name{1}).metrics(3).mae, results.noise);
    plot(sigmas, y, '-o', 'LineWidth', 1.2, 'DisplayName', name{1});
end
xlabel('Gaussian noise sigma (pixel scale)'); ylabel('Z MAE (mm)');
saveas(fig, fullfile(cfg.output.figures, 'fig_noise_robustness.png'));
close(fig);

% 合成噪声底分析。
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 700]);
amp = cfg.amplitudeLevels;
rmsTrue = [results.amplitude.rms];
rmse = arrayfun(@(x) x.metrics(3).rmse, results.amplitude);
snr = arrayfun(@(x) x.metrics(3).snr, results.amplitude);
subplot(2, 1, 1); loglog(amp, rmsTrue, 'ko-', amp, rmse, 'b^-', 'LineWidth', 1.2); grid on;
xlabel('Input amplitude (mm)'); ylabel('RMS (mm)'); legend('Truth', 'Error RMSE', 'Location', 'best');
subplot(2, 1, 2); semilogx(amp, snr, 'rs-', 'LineWidth', 1.2); grid on;
xlabel('Input amplitude (mm)'); ylabel('SNR (dB)');
saveas(fig, fullfile(cfg.output.figures, 'fig_amplitude_noise_floor.png'));
close(fig);

% 过程图：一帧双目合成图，对应论文 Fig. 5 的 simulated image。
[preview, ~] = simulate_stereo_sequence(cfg, 0);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 850 400]);
subplot(1, 2, 1); imagesc(preview{1}(:, :, 1)); axis image off; colormap gray; title('Camera 1');
subplot(1, 2, 2); imagesc(preview{2}(:, :, 1)); axis image off; colormap gray; title('Camera 2');
saveas(fig, fullfile(cfg.output.process, 'process_stereo_preview.png'));
close(fig);
end

function write_noise_csv(results)
cfg = results.config;
path = fullfile(cfg.output.figures, 'noise_metrics.csv');
fid = fopen(path, 'w');
fprintf(fid, 'sigma,method,x_corr,y_corr,z_corr,x_mae,y_mae,z_mae\n');
for k = 1:numel(results.noise)
    for name = {'generic', 'geometry', 'pofcm'}
        m = results.noise(k).(name{1}).metrics;
        fprintf(fid, '%g,%s,%g,%g,%g,%g,%g,%g\n', results.config.noiseLevels(k), name{1}, ...
            m(1).corr, m(2).corr, m(3).corr, m(1).mae, m(2).mae, m(3).mae);
    end
end
fclose(fid);
end
