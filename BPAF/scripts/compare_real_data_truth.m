%% COMPARE_REAL_DATA_TRUTH
% 批量比较 BPAF 真实视频结果与三角光 LDV 真值。
%
% 处理范围：
%   outputs/07-26_single/* 和 outputs/0819/*
%   分别在 E:/sanjiao/0726 和 E:/sanjiao/0819 查找同名 CSV。
%   三角光 CSV 的第 3 列作为对比真值，采样率固定为 100 Hz。
%
% 对齐约定：三角光先开始采集、视频后开始采集，因此脚本只在真值序列
% 中搜索一个非负起始位置，使其与 BPAF 波形的重叠段相关性最大。BPAF
% 和三角光的物理单位可能不同，波形图采用去趋势后的零均值/单位标准差
% 归一化；频谱也分别归一化到峰值 1，避免把单位差异误认为算法误差。
%
% 输出（每个有对应真值的 BPAF 视频目录）：
%   comparison/<视频名>_waveform_comparison.png/.fig
%   comparison/<视频名>_spectrum_comparison.png/.fig
%   comparison/<视频名>_comparison_metrics.csv
%   comparison/<视频名>_comparison_data.mat
%
% 没有三角光文件的目录（当前包括 sun-3050-30mvpp）会自动跳过并打印原因。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot,'src'));
cfg = bpaf.default_config();
bpaf.setup_project(cfg);

% 三角光真值根目录；如果移动数据位置，只修改这里。
truthRoots = struct('folder', {fullfile('E:','sanjiao','0726'), ...
                               fullfile('E:','sanjiao','0819')}, ...
                    'outputRoot', {fullfile(cfg.outputDir,'07-26_single'), ...
                                   fullfile(cfg.outputDir,'0819')});
truthFs = 100;                         % 三角光 LDV 采样率（Hz）
maxDelaySeconds = 30;                  % 允许真值先于视频的最大时差
frequencyRangeHz = [0.05 50];          % 与 BPAF 真实视频图保持一致

for rootIdx = 1:numel(truthRoots)
    outputRoot = truthRoots(rootIdx).outputRoot;
    truthRoot = truthRoots(rootIdx).folder;
    if ~isfolder(outputRoot)
        fprintf('跳过：BPAF 输出目录不存在：%s\n',outputRoot);
        continue;
    end
    if ~isfolder(truthRoot)
        fprintf('跳过：三角光目录不存在：%s\n',truthRoot);
        continue;
    end

    signalFiles = dir(fullfile(outputRoot,'**','05_bpaf_vibration_signal.csv'));
    for fileIdx = 1:numel(signalFiles)
        signalPath = fullfile(signalFiles(fileIdx).folder,signalFiles(fileIdx).name);
        videoFolder = signalFiles(fileIdx).folder;
        [videoName,runConfig] = read_video_name(videoFolder);
        if isempty(videoName)
            fprintf('跳过：无法确定视频名：%s\n',videoFolder);
            continue;
        end

        truthPath = fullfile(truthRoot,[videoName '.csv']);
        if ~isfile(truthPath)
            fprintf('跳过：没有同名三角光真值（%s）：%s\n',videoName,videoFolder);
            continue;
        end

        try
            [bpafSignal,bpafFs] = read_bpaf_signal(signalPath,runConfig);
            truthSignal = read_truth_column(truthPath,3);
            if numel(bpafSignal) < 16 || numel(truthSignal) < 16
                error('有效样本数不足（BPAF=%d，三角光=%d）',numel(bpafSignal),numel(truthSignal));
            end

            comparison = align_and_compare(bpafSignal,bpafFs,truthSignal,truthFs, ...
                maxDelaySeconds,frequencyRangeHz);
            comparison.videoName = videoName;
            comparison.videoFolder = videoFolder;
            comparison.truthPath = truthPath;
            comparison.bpafSignalPath = signalPath;

            comparisonFolder = fullfile(videoFolder,'comparison');
            if ~isfolder(comparisonFolder), mkdir(comparisonFolder); end
            save_comparison_figures(comparison,comparisonFolder,videoName,frequencyRangeHz);
            save_comparison_data(comparison,comparisonFolder,videoName);
            fprintf('完成对比：%s | delay=%.3f s | waveform r=%.4f | spectrum r=%.4f\n', ...
                videoName,comparison.delaySeconds,comparison.waveformCorrelation, ...
                comparison.spectrumCorrelation);
        catch err
            fprintf(2,'对比失败：%s\n  %s\n',videoFolder,err.message);
        end
    end
end

fprintf('批量三角光对比完成。\n');

function [videoName,runConfig] = read_video_name(videoFolder)
% 优先使用真实视频运行时保存的 outputName，保证与输入视频基名一致。
videoName = '';
runConfig = struct('processingFps',100);
matPath = fullfile(videoFolder,'06_bpaf_run_result.mat');
if isfile(matPath)
    loaded = load(matPath,'runConfig');
    if isfield(loaded,'runConfig')
        runConfig = loaded.runConfig;
        if isfield(runConfig,'outputName') && ~isempty(runConfig.outputName)
            videoName = char(runConfig.outputName);
        end
    end
end
if isempty(videoName)
    [~,videoName] = fileparts(videoFolder);
end
% 文件名来自视频/输出目录，不允许路径分隔符进入真值文件名。
videoName = regexprep(videoName,'[\\/:*?"<>|]','_');
end

function [signal,fs] = read_bpaf_signal(signalPath,runConfig)
% 05 文件第 2 列是 BPAF 滤波后的相位信号，第 1 列为相对时间。
tableData = readmatrix(signalPath);
if size(tableData,2) < 2
    error('BPAF 信号 CSV 至少需要两列：%s',signalPath);
end
signal = double(tableData(:,2));
valid = isfinite(signal);
signal = signal(valid);
fs = 100;
if isfield(runConfig,'processingFps') && isfinite(runConfig.processingFps) && runConfig.processingFps > 0
    fs = double(runConfig.processingFps);
end
end

function signal = read_truth_column(truthPath,columnIndex)
% 三角光文件没有统一表头，readmatrix 后直接取第 3 列。
truthMatrix = readmatrix(truthPath);
if size(truthMatrix,2) < columnIndex
    error('三角光 CSV 不包含第 %d 列：%s',columnIndex,truthPath);
end
signal = double(truthMatrix(:,columnIndex));
valid = isfinite(signal);
if ~any(valid)
    error('三角光第 %d 列没有有效数值：%s',columnIndex,truthPath);
end
if any(~valid)
    sampleIndex = (1:numel(signal)).';
    signal(~valid) = interp1(sampleIndex(valid),signal(valid),sampleIndex(~valid),'linear','extrap');
end
signal = signal(:);
end

function comparison = align_and_compare(bpafSignal,bpafFs,truthSignal,truthFs,maxDelaySeconds,frequencyRangeHz)
% 先统一到三角光的 100 Hz，再在真值中搜索视频对应的起点。
bpafSignal = bpafSignal(:);
truthSignal = truthSignal(:);
if abs(bpafFs-truthFs) > 1e-9
    oldTime = (0:numel(bpafSignal)-1)'/bpafFs;
    newCount = max(2,round((numel(bpafSignal)-1)*truthFs/bpafFs)+1);
    newTime = (0:newCount-1)'/truthFs;
    bpafSignal = interp1(oldTime,bpafSignal,newTime,'linear','extrap');
end

% 禁止用短尾段“碰巧相关”来决定时差；至少保留两段信号较短者的 90%。
% 当前三角光记录均长于视频，因此该约束基本覆盖整个视频，避免只比较局部片段。
minOverlap = max(16,round(0.90*min(numel(bpafSignal),numel(truthSignal))));
maxStart = min(numel(truthSignal)-minOverlap,round(maxDelaySeconds*truthFs));
best = struct('score',-Inf,'startIndex',1,'sign',1,'overlap',0);
for startIndex = 1:(maxStart+1)
    overlap = min(numel(bpafSignal),numel(truthSignal)-startIndex+1);
    if overlap < minOverlap, continue; end
    x = normalized_for_alignment(bpafSignal(1:overlap));
    y = normalized_for_alignment(truthSignal(startIndex:startIndex+overlap-1));
    correlation = mean(x.*y);
    if abs(correlation) > best.score
        best.score = abs(correlation);
        best.startIndex = startIndex;
        best.sign = sign(correlation);
        if best.sign == 0, best.sign = 1; end
        best.overlap = overlap;
    end
end
if ~isfinite(best.score)
    error('无法找到满足长度要求的时间对齐区间');
end

overlap = best.overlap;
bpafAligned = bpafSignal(1:overlap);
truthAligned = truthSignal(best.startIndex:best.startIndex+overlap-1);
bpafNorm = normalized_for_alignment(bpafAligned);
truthNorm = normalized_for_alignment(truthAligned);
% 相关性搜索允许正负方向；比较图将 BPAF 方向校正到真值方向，保留原始符号信息。
bpafNorm = best.sign*bpafNorm;

[frequency,bpafSpectrum] = normalized_spectrum(bpafAligned,truthFs);
[truthFrequency,truthSpectrum] = normalized_spectrum(truthAligned,truthFs);
common = frequency >= frequencyRangeHz(1) & frequency <= min(frequencyRangeHz(2),truthFs/2);
truthCommon = interp1(truthFrequency,truthSpectrum,frequency(common),'linear',0);
bpafCommon = bpafSpectrum(common);
if all(bpafCommon==0) || all(truthCommon==0)
    spectrumCorrelation = NaN;
else
    spectrumCorrelation = corr(bpafCommon(:),truthCommon(:),'Rows','complete');
end

comparison = struct();
comparison.fs = truthFs;
comparison.bpafFsOriginal = bpafFs;
comparison.delaySeconds = (best.startIndex-1)/truthFs;
comparison.truthStartSample = best.startIndex;
comparison.alignmentCorrelationAbs = best.score;
comparison.alignmentSign = best.sign;
comparison.time = (0:overlap-1)'/truthFs;
comparison.bpafRaw = bpafAligned;
comparison.truthRaw = truthAligned;
comparison.bpafNormalized = bpafNorm;
comparison.truthNormalized = truthNorm;
comparison.frequency = frequency;
comparison.bpafSpectrum = bpafSpectrum;
comparison.truthFrequency = truthFrequency;
comparison.truthSpectrum = truthSpectrum;
comparison.waveformCorrelation = corr(bpafNorm,truthNorm,'Rows','complete');
comparison.waveformRMSE = sqrt(mean((bpafNorm-truthNorm).^2));
comparison.spectrumCorrelation = spectrumCorrelation;
comparison.bpafPeakHz = peak_frequency(frequency,bpafSpectrum,frequencyRangeHz);
comparison.truthPeakHz = peak_frequency(truthFrequency,truthSpectrum,frequencyRangeHz);
end

function output = normalized_for_alignment(input)
input = double(input(:));
sampleIndex = (0:numel(input)-1)';
if numel(input) >= 3
    trend = polyfit(sampleIndex,input,1);
    input = input-polyval(trend,sampleIndex);
else
    input = input-mean(input);
end
output = (input-mean(input))/max(std(input),eps);
end

function [frequency,spectrum] = normalized_spectrum(signal,fs)
signal = normalized_for_alignment(signal);
n = numel(signal);
nfft = 2^nextpow2(n);
transform = abs(fft(signal,nfft));
count = floor(nfft/2)+1;
spectrum = transform(1:count);
frequency = (0:count-1)'*fs/nfft;
spectrum = spectrum/max(max(spectrum),eps);
end

function peakHz = peak_frequency(frequency,spectrum,frequencyRangeHz)
mask = frequency >= frequencyRangeHz(1) & frequency <= min(frequencyRangeHz(2),frequency(end));
if ~any(mask)
    peakHz = NaN;
    return;
end
frequencyMasked = frequency(mask);
spectrumMasked = spectrum(mask);
[~,idx] = max(spectrumMasked);
peakHz = frequencyMasked(idx);
end

function save_comparison_figures(comparison,comparisonFolder,videoName,frequencyRangeHz)
% 波形图：BPAF 黑色实线，三角光 LDV 红色虚线。
safeName = regexprep(videoName,'[^A-Za-z0-9_\-]','_');
fig = figure('Visible','off','Color','w','Position',[100 100 1000 700]);
subplot(2,1,1);
plot(comparison.time,comparison.bpafNormalized,'k-','LineWidth',1.0); hold on;
plot(comparison.time,comparison.truthNormalized,'r--','LineWidth',1.0); hold off; grid on;
xlabel('Time (s)'); ylabel('Normalized amplitude'); title('BPAF vs triangular-light LDV waveform');
legend({'BPAF','Triangular-light LDV'},'Location','best');
subplot(2,1,2);
plot(comparison.time,comparison.bpafRaw,'k-','LineWidth',0.8); hold on;
plot(comparison.time,comparison.truthRaw,'r--','LineWidth',0.8); hold off; grid on;
xlabel('Time (s)'); ylabel('Original units'); title(sprintf('Aligned raw signals (delay = %.3f s)',comparison.delaySeconds));
set(findall(fig,'Type','axes'),'FontName','Times New Roman','FontSize',11,'LineWidth',0.8);
exportgraphics(fig,fullfile(comparisonFolder,[safeName '_waveform_comparison.png']),'Resolution',220);
set(fig,'Visible','on');
saveas(fig,fullfile(comparisonFolder,[safeName '_waveform_comparison.fig']),'fig');
close(fig);

% 频谱图采用统一 100 Hz 频率轴和归一化幅值。
fig = figure('Visible','off','Color','w','Position',[100 100 1000 560]);
ax = axes(fig);
plot(ax,comparison.frequency,comparison.bpafSpectrum,'k-','LineWidth',1.0); hold(ax,'on');
plot(ax,comparison.truthFrequency,comparison.truthSpectrum,'r--','LineWidth',1.0); hold(ax,'off'); grid(ax,'on');
xlim(ax,[max(0,frequencyRangeHz(1)),min(frequencyRangeHz(2),comparison.fs/2)]);
xlabel(ax,'Frequency (Hz)'); ylabel(ax,'Normalized amplitude');
title(ax,sprintf('%s | BPAF vs triangular-light LDV spectrum (%.3f / %.3f Hz)', ...
    strrep(videoName,'_','\_'),comparison.bpafPeakHz,comparison.truthPeakHz), ...
    'FontName','Times New Roman','FontSize',13,'FontWeight','normal');
legend(ax,{'BPAF','Triangular-light LDV'},'Location','best');
set(ax,'FontName','Times New Roman','FontSize',11,'LineWidth',0.8);
exportgraphics(fig,fullfile(comparisonFolder,[safeName '_spectrum_comparison.png']),'Resolution',220);
set(fig,'Visible','on');
saveas(fig,fullfile(comparisonFolder,[safeName '_spectrum_comparison.fig']),'fig');
close(fig);
end

function save_comparison_data(comparison,comparisonFolder,videoName)
safeName = regexprep(videoName,'[^A-Za-z0-9_\-]','_');
metrics = table(comparison.delaySeconds,comparison.alignmentCorrelationAbs, ...
    comparison.waveformCorrelation,comparison.waveformRMSE,comparison.spectrumCorrelation, ...
    comparison.bpafPeakHz,comparison.truthPeakHz, ...
    'VariableNames',{'delay_s','alignment_abs_corr','waveform_corr','waveform_rmse', ...
                     'spectrum_corr','bpaf_peak_hz','truth_peak_hz'});
writetable(metrics,fullfile(comparisonFolder,[safeName '_comparison_metrics.csv']));
save(fullfile(comparisonFolder,[safeName '_comparison_data.mat']),'comparison','-v7.3');
end
