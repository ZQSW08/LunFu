function results = run_all(cfg)
%RUN_ALL 完成论文可软件复现的全部阶段并导出正式结果。

arguments
    cfg struct = bpaf.default_config()
end
bpaf.setup_project(cfg);
rng(cfg.randomSeed, 'twister');

specs = bpaf.dataset_specs(cfg);
datasets = cell(1, numel(specs));
features = cell(1, numel(specs));
for idx = 1:numel(specs)
    fprintf('[BPAF] 生成/载入数据集 %s...\n', specs(idx).id);
    datasets{idx} = bpaf.generate_dataset(specs(idx), cfg);
    fprintf('[BPAF] 提取局部相位 %s...\n', specs(idx).id);
    features{idx} = bpaf.extract_phase_features(datasets{idx}, cfg);
end

results = struct();
results.config = cfg;
results.specs = specs;
results.generatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

% 图5：三个论文示例通带的参数化 BPAF。
demoBands = [3 12; 3 18; 10 30];
for idx = 1:size(demoBands, 1)
    [k, info] = bpaf.design_bpaf_kernel(120, demoBands(idx,1), demoBands(idx,2), ...
        demoBands(idx,2)+5, cfg.stopbandAlpha, cfg, true);
    results.filterDemo(idx) = struct('band', demoBands(idx,:), 'kernel', k, 'info', info); %#ok<AGROW>
end

% 4.2：SV1/SV2 正式对比、消融和复杂度。
methodNames = {'Acc2017', 'Acc2018', 'Acc2022', 'BPAF'};
for caseIdx = 1:2
    f = features{caseIdx};
    for methodIdx = 1:numel(methodNames)
        if methodIdx < 4
            prior = 50;
        else
            prior = [10 60];
        end
        tic;
        results.sim(caseIdx).methods(methodIdx) = bpaf.run_method( ...
            f, methodNames{methodIdx}, prior, cfg, 'cube', methodIdx==4);
        results.sim(caseIdx).runtime(methodIdx) = toc;
    end
    results.sim(caseIdx).pve = bpaf.run_method(f, 'PVE', 0, cfg, 'aggregate', false);
    results.sim(caseIdx).bp = bpaf.run_method(f, 'BP', [10 60], cfg, 'cube', true);
    results.sim(caseIdx).id = specs(caseIdx).id;
    results.sim(caseIdx).time = f.time;
    results.sim(caseIdx).truth = f.truthVibration;
    results.sim(caseIdx).rawSignal = f.rawSignal;
end

% 图13：BPAF 先验上限扫描；图14：三种对比核的估计频率扫描。
fhValues = 20:100;
feValues = 15:55;
for caseIdx = 1:2
    f = features{caseIdx};
    for idx = 1:numel(fhValues)
        r = bpaf.run_method(f, 'BPAF', [10 fhValues(idx)], cfg, 'cube', false);
        results.simPerformance(caseIdx).bpafPF(idx) = r.metrics.PF;
        results.simPerformance(caseIdx).bpafPER(idx) = r.metrics.PER;
    end
    for methodIdx = 1:3
        for idx = 1:numel(feValues)
            r = bpaf.run_method(f, methodNames{methodIdx}, feValues(idx), cfg, 'cube', false);
            results.simPerformance(caseIdx).accPF(methodIdx, idx) = r.metrics.PF;
            results.simPerformance(caseIdx).accPER(methodIdx, idx) = r.metrics.PER;
        end
    end
    results.simPerformance(caseIdx).id = specs(caseIdx).id;
    results.simPerformance(caseIdx).fhValues = fhValues;
    results.simPerformance(caseIdx).feValues = feValues;
end

% 4.3：移动激振器真实实验缺少原视频，使用论文参数等价模拟代理。
exciterBands = [20 50; 20 40; 30 40];
exciterFE = [50 20 30];
f = features{3};
for level = 1:3
    for methodIdx = 1:4
        if methodIdx < 4
            prior = exciterFE(level);
        else
            prior = exciterBands(level,:);
        end
        results.exciter.methods(level, methodIdx) = bpaf.run_method( ...
            f, methodNames{methodIdx}, prior, cfg, 'cube', methodIdx==4);
    end
end
gridValues = 10:10:90;
results.exciter.gridPF = nan(numel(gridValues));
results.exciter.gridPER = nan(numel(gridValues));
for row = 1:numel(gridValues)
    fl = gridValues(row);
    for col = 1:numel(gridValues)
        fh = gridValues(col);
        if fl < fh
            r = bpaf.run_method(f, 'BPAF', [fl fh], cfg, 'cube', false);
            results.exciter.gridPF(row,col) = r.metrics.PF;
            results.exciter.gridPER(row,col) = r.metrics.PER;
        end
    end
end
results.exciter.gridValues = gridValues;
results.exciter.time = f.time;
results.exciter.truth = f.truthVibration;

% 4.4：移动/静止悬臂梁等价模拟；静止 PME 频谱作为论文式(36)真值。
moving = features{4};
stationary = features{5};
ground = bpaf.run_method(stationary, 'PVE', 0, cfg, 'aggregate', false);
% 真实论文没有位移真值，故用静止底座视频 PME 作参考；等价模拟拥有精确
% 位移真值，PCC 直接对真值频谱计算，避免把代理视频的成像噪声误当成结构响应。
ground.signal = stationary.truthVibration;
ground.metrics = bpaf.evaluate_signal(ground.signal, stationary.truthVibration, ...
    stationary.fs, 0);
ground.source = 'synthetic-displacement-truth';
beamBands = [4 30; 4 15; 4 6];
beamFE = [20 10 5];
for level = 1:3
    for methodIdx = 1:4
        if methodIdx < 4
            prior = beamFE(level);
        else
            prior = beamBands(level,:);
        end
        r = bpaf.run_method(moving, methodNames{methodIdx}, prior, cfg, ...
            'cube', methodIdx==4);
        r.metrics.PCC = spectrum_pcc(r.metrics.spectrum, ground.metrics.spectrum);
        results.beam.methods(level, methodIdx) = r;
    end
end
limitBands = [4 40; 4 50; 3 50; 2 50];
for idx = 1:size(limitBands,1)
    r = bpaf.run_method(moving, 'BPAF', limitBands(idx,:), cfg, 'cube', false);
    r.metrics.PCC = spectrum_pcc(r.metrics.spectrum, ground.metrics.spectrum);
    results.beam.limits(idx) = r;
end
results.beam.limitBands = limitBands;
results.beam.ground = ground;
results.beam.time = moving.time;
results.beam.truth = moving.truthVibration;

bpaf.write_tables(results, cfg);
bpaf.plot_results(results, datasets, cfg);
save(fullfile(cfg.resultDir, 'reproduction_results.mat'), 'results', '-v7.3');
fprintf('[BPAF] 全部可软件复现实验完成。\n');
end

function value = spectrum_pcc(x, y)
n = min(numel(x), numel(y));
x = double(x(1:n));
y = double(y(1:n));
c = corrcoef(x, y);
if numel(c) < 4 || ~isfinite(c(1,2))
    value = NaN;
else
    value = c(1,2);
end
end
