function summary = apcv_run_reproduction(cfg)
%APCV_RUN_REPRODUCTION 完整运行论文方法和全部等价合成实验。

rng(cfg.randomSeed, 'twister');
outputDirs = {cfg.paths.figures,cfg.paths.process,cfg.paths.videos,cfg.paths.data};
for i = 1:numel(outputDirs)
    if ~exist(outputDirs{i}, 'dir'); mkdir(outputDirs{i}); end
end

startTime = tic;
lab = apcv_run_site('lab', cfg);
bridge = apcv_run_site('bridge', cfg);
apcv_write_metric_tables(lab, bridge, cfg);

% 先保存曲线、模型参数和真值，再绘图；若图形后端失败，数值结果仍可恢复。
% 不保存重复的逐帧金字塔缓存。
labForSave = stripCache(lab);
bridgeForSave = stripCache(bridge);
save(fullfile(cfg.paths.data,'reproduction_results.mat'), ...
    'labForSave','bridgeForSave','cfg','-v7.3');
apcv_plot_reproduction(labForSave, bridgeForSave, cfg);

summary.elapsedSeconds = toc(startTime);
summary.labSelectedLevel = lab.model.selectedLevel;
summary.bridgeSelectedLevel = bridge.model.selectedLevel;
summary.labMeanRmse = mean(arrayfun(@(x)x.metrics.proposed.rmse,lab.results));
summary.bridgeMeanRmse = mean(arrayfun(@(x)x.metrics.proposed.rmse,bridge.results));
summary.labMeanAmplitudeRmse = mean(arrayfun(@(x)x.metrics.amplitudeOnly.rmse,lab.results));
summary.bridgeMeanExistingRmse = mean(arrayfun(@(x)x.metrics.existingScale.rmse,bridge.results));
save(fullfile(cfg.paths.data,'reproduction_summary.mat'),'summary');
fprintf('\nCompleted in %.1f s | Lab RMSE %.4f mm | Bridge RMSE %.4f mm\n', ...
    summary.elapsedSeconds,summary.labMeanRmse,summary.bridgeMeanRmse);
end

function site = stripCache(site)
if isfield(site.model,'calibrationCache')
    site.model = rmfield(site.model,'calibrationCache');
end
site = rmfield(site,'canvas');
end
