%EXPORT_EXISTING_REAL_FIGURES 为已经完成的真实视频结果补导出独立图片和 FIG 文件。
% 不重新读取视频、不重新框选 ROI、不重新运行 BPAF；只读取各输出目录中的 MAT 结果。

close all; clc;
scriptPath=mfilename('fullpath');
projectRoot=fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot,'src'));
cfg=bpaf.default_config();
bpaf.setup_project(cfg);

resultFiles=dir(fullfile(cfg.outputDir,'**','06_bpaf_run_result.mat'));
if isempty(resultFiles)
    fprintf('未找到 06_bpaf_run_result.mat，无需导出。\n');
    return;
end

for idx=1:numel(resultFiles)
    resultPath=fullfile(resultFiles(idx).folder,resultFiles(idx).name);
    loaded=load(resultPath,'result','features','runConfig');
    if ~isfield(loaded,'result') || ~isfield(loaded,'features')
        fprintf('跳过不完整结果：%s\n',resultPath);
        continue;
    end
    if isfield(loaded,'runConfig') && isfield(loaded.runConfig,'processingFps')
        fs=loaded.runConfig.processingFps;
    else
        fs=loaded.features.fs;
    end
    if isfield(loaded,'runConfig') && isfield(loaded.runConfig,'frequencyRangeHz')
        frequencyRange=loaded.runConfig.frequencyRangeHz;
    else
        frequencyRange=[0.05 fs/2];
    end
    if isfield(loaded,'runConfig') && isfield(loaded.runConfig,'bpaf') && ...
            isfield(loaded.runConfig.bpaf,'frequencyBandHz')
        band=loaded.runConfig.bpaf.frequencyBandHz;
    else
        band=[max(0.05,frequencyRange(1)),min(frequencyRange(2),fs/2)];
    end
    band=sort(double(band(:).'));
    band(1)=max(band(1),eps); band(2)=min(band(2),fs/2-eps);
    if band(2)<=band(1), band=[max(eps,fs/100),min(fs/4,fs/2-eps)]; end
    if isfield(loaded,'runConfig') && isfield(loaded.runConfig,'outputName')
        name=loaded.runConfig.outputName;
    else
        [~,name]=fileparts(resultFiles(idx).folder);
    end
    time=(0:numel(loaded.result.signal)-1)'/fs;
    bpaf.export_real_figures(loaded.result,loaded.features.rawSignal,time, ...
        frequencyRange,band,fs,resultFiles(idx).folder,name);
    fprintf('已补导出：%s\n',resultFiles(idx).folder);
end
fprintf('独立波形/频谱 PNG 与 FIG 导出完成。\n');
