function refresh_result_plots(resultRoot)
%REFRESH_RESULT_PLOTS 用当前绘图规范重建已有结果目录中的 PNG/FIG/MAT。
% 不重新读取视频、不改变轨迹，只更新显示：原始 FFT + Hann 窗 FFT。
if nargin < 1 || isempty(resultRoot), error('Crossline:Input','请提供结果根目录。'); end
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
d=dir(resultRoot); d=d([d.isdir]); d=d(~ismember({d.name},{'.','..'}));
for i=1:numel(d)
    outDir=fullfile(d(i).folder,d(i).name);
    q=fullfile(outDir,'crossline_results.mat');
    if ~isfile(q), continue; end
    S=load(q,'cfg','trajectoryTable','valid','globalCenter');
    if isfield(S.cfg.real,'processingFps'), fps=S.cfg.real.processingFps; else, fps=S.cfg.real.videoFps; end
    [~,nm,ext]=fileparts(S.cfg.real.videoPath);
    expected=[];
    if isfield(S.cfg.real,'expectedFrequenciesHz'), expected=S.cfg.real.expectedFrequenciesHz; end
    truthPath=fullfile(fileparts(S.cfg.real.videoPath),[nm '_truth.mat']);
    if isempty(expected) && isfile(truthPath)
        try, T=load(truthPath,'cfg'); if isfield(T.cfg,'microFrequencyHz'), expected=T.cfg.microFrequencyHz; end; catch, end
    end
    meta=struct('videoName',[nm ext],'roi',S.cfg.real.actualRoi,'videoFps',S.cfg.real.videoFps,'processingFps',fps,'expectedFrequenciesHz',expected);
    [~,~,spectrum]=plot_real_results(S.trajectoryTable.time_s,S.globalCenter,S.valid,fps,outDir,meta); %#ok<ASGLU>
    rs=struct();
    if ~isempty(whos('-file',q,'runtimeSummary'))
        Q=load(q,'runtimeSummary'); rs=Q.runtimeSummary;
    end
    write_real_output_readme(outDir,S.cfg.real.videoPath,S.cfg.real.actualRoi,fps,height(S.trajectoryTable),mean(S.valid),rs);
    close all;
    fprintf('已刷新：%s\n',outDir);
end
end
