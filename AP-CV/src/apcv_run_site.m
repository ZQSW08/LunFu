function site = apcv_run_site(siteName, cfg)
%APCV_RUN_SITE 运行单层建筑或人行桥的一组等价合成实验。

cases = apcv_case_definitions(siteName, cfg);
switch lower(siteName)
    case 'lab'
        gamma = cfg.lab.gammaMmPerPixel;
        noise = cfg.lab.noiseSigma;
        drift = cfg.lab.illuminationDrift;
        textureSeed = cfg.lab.textureSeed;
        textureStyle = 'lab';
        calibrationCase = 1;
    case 'bridge'
        gamma = cfg.bridge.gammaMmPerPixel;
        noise = cfg.bridge.noiseSigma;
        drift = cfg.bridge.illuminationDrift;
        textureSeed = cfg.bridge.textureSeed;
        textureStyle = 'bridge';
        calibrationCase = 4;
    otherwise
        error('未知站点: %s', siteName);
end

canvas = apcv_generate_texture(cfg.imageSize, cfg.canvasMargin, ...
    textureSeed, textureStyle);
calibrationTruthPx = cases(calibrationCase).truthMm / gamma;
calibrationFrames = apcv_generate_sequence(canvas, cfg.imageSize, ...
    cfg.canvasMargin, calibrationTruthPx, noise, drift, ...
    cfg.randomSeed + 1000*calibrationCase + textureSeed);

if cfg.verbose
    fprintf('\n[%s] calibration with %s (%d frames)\n', upper(siteName), ...
        cases(calibrationCase).name, size(calibrationFrames, 3));
end
model = apcv_calibrate_model(calibrationFrames, gamma, cfg);
if cfg.verbose
    fprintf('[%s] selected pyramid level: %d, scale: %.4f px/rad\n', ...
        upper(siteName), model.selectedLevel, ...
        model.levels(model.selectedIndex).scaleSelf);
end

if cfg.saveVideos
    videoPath = fullfile(cfg.paths.videos, sprintf('%s_synthetic_input.avi', siteName));
    apcv_write_video(calibrationFrames, videoPath, cfg.frameRate, cfg.videoMaxFrames);
end

resultTemplate = struct('name', '', 'time', [], 'truthMm', [], ...
    'estimate', [], 'metrics', []);
results = repmat(resultTemplate, numel(cases), 1);
for i = 1:numel(cases)
    if i == calibrationCase
        frames = calibrationFrames;
    else
        truthPx = cases(i).truthMm / gamma;
        frames = apcv_generate_sequence(canvas, cfg.imageSize, cfg.canvasMargin, ...
            truthPx, noise, drift, cfg.randomSeed + 1000*i + textureSeed);
    end
    estimate = apcv_estimate_sequence(frames, model, cfg);
    metrics.proposed = apcv_compute_metrics(estimate.proposedMm, cases(i).truthMm);
    metrics.amplitudeOnly = apcv_compute_metrics(estimate.amplitudeOnlyMm, cases(i).truthMm);
    metrics.existingScale = apcv_compute_metrics(estimate.existingScaleMm, cases(i).truthMm);
    metrics.allPixels = apcv_compute_metrics(estimate.allPixelsMm, cases(i).truthMm);
    metrics.amplitudeMask = apcv_compute_metrics(estimate.amplitudeMaskMm, cases(i).truthMm);
    firstLevelMetric = apcv_compute_metrics(estimate.byLevelMm(:, 1), ...
        cases(i).truthMm);
    metrics.byLevel = repmat(firstLevelMetric, numel(cfg.pyramidLevels), 1);
    for levelIndex = 2:numel(cfg.pyramidLevels)
        metrics.byLevel(levelIndex) = apcv_compute_metrics( ...
            estimate.byLevelMm(:, levelIndex), cases(i).truthMm);
    end
    results(i).name = cases(i).name;
    results(i).time = cases(i).time;
    results(i).truthMm = cases(i).truthMm;
    results(i).estimate = estimate;
    results(i).metrics = metrics;
    if cfg.verbose
        fprintf('[%s] %-18s proposed %.4f mm | amplitude %.4f mm\n', ...
            upper(siteName), cases(i).name, metrics.proposed.rmse, ...
            metrics.amplitudeOnly.rmse);
    end
end

site.name = siteName;
site.gammaMmPerPixel = gamma;
site.canvas = canvas;
site.referenceImage = calibrationFrames(:, :, 1);
site.calibrationCase = calibrationCase;
site.model = model;
site.results = results;
end
