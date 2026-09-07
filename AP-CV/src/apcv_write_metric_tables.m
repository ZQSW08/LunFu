function apcv_write_metric_tables(lab, bridge, cfg)
%APCV_WRITE_METRIC_TABLES 导出底层数值，保证所有图表均可追溯。

writeSite(lab, fullfile(cfg.paths.data, 'lab_metrics.csv'), cfg);
writeSite(bridge, fullfile(cfg.paths.data, 'bridge_metrics.csv'), cfg);

function writeSite(site, path, localCfg)
    n = numel(site.results);
    caseName = strings(n, 1);
    proposedRmse = zeros(n, 1); amplitudeRmse = zeros(n, 1);
    existingRmse = zeros(n, 1); allPixelsRmse = zeros(n, 1);
    amplitudeMaskRmse = zeros(n, 1);
    levelRmse = zeros(n, numel(localCfg.pyramidLevels));
    for k = 1:n
        r = site.results(k);
        caseName(k) = string(r.name);
        proposedRmse(k) = r.metrics.proposed.rmse;
        amplitudeRmse(k) = r.metrics.amplitudeOnly.rmse;
        existingRmse(k) = r.metrics.existingScale.rmse;
        allPixelsRmse(k) = r.metrics.allPixels.rmse;
        amplitudeMaskRmse(k) = r.metrics.amplitudeMask.rmse;
        for j = 1:numel(localCfg.pyramidLevels)
            levelRmse(k, j) = r.metrics.byLevel(j).rmse;
        end
    end
    tableValue = table(caseName, proposedRmse, amplitudeRmse, existingRmse, ...
        allPixelsRmse, amplitudeMaskRmse);
    for j = 1:numel(localCfg.pyramidLevels)
        tableValue.(sprintf('level%dRmse', localCfg.pyramidLevels(j))) = levelRmse(:, j);
    end
    writetable(tableValue, path);
end
end
