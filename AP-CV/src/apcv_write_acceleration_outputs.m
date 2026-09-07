function outputs = apcv_write_acceleration_outputs(rootDirectory)
%APCV_WRITE_ACCELERATION_OUTPUTS 从已有位移 CSV 计算加速度波形和频谱。
%
% 只使用 amplitude-phase fusion 的 proposed_*_px 列，不使用 amplitude-only
% 或 phase residual 列。加速度采用时间轴上的二阶数值导数，单位为 pixel/s^2。
% 每个结果目录生成 PNG 和 MATLAB FIG；保存 FIG 前显式设为 Visible=on，
% 便于 Windows 双击打开。原始 CSV、MAT 和已有位移图不作修改。

if nargin < 1 || isempty(rootDirectory), rootDirectory = pwd; end
rootDirectory = char(rootDirectory);
files = localFindDisplacementCsv(rootDirectory);
outputs = repmat(struct('csvPath','','accelerationCsv','','waveformPng','', ...
    'waveformFig','','spectrumPng','','spectrumFig',''),numel(files),1);
for k = 1:numel(files)
    csvPath = fullfile(files(k).folder,files(k).name);
    stem = erase(files(k).name,'_displacement.csv');
    outputs(k) = localProcessOne(csvPath,files(k).folder,stem);
end
fprintf('加速度输出完成：%d 个结果目录。\n',numel(outputs));
end

function files = localFindDisplacementCsv(rootDirectory)
% 递归查找已有位移结果，避免写死风洞项目的子目录名称。
files = dir(fullfile(rootDirectory,'*_displacement.csv'));
children = dir(rootDirectory);
for k = 1:numel(children)
    if children(k).isdir && ~any(strcmp(children(k).name,{'.','..'}))
        files = [files; localFindDisplacementCsv(fullfile(rootDirectory,children(k).name))]; %#ok<AGROW>
    end
end
end

function output = localProcessOne(csvPath,outputDirectory,stem)
tableValue = readtable(csvPath);
names = tableValue.Properties.VariableNames;
candidate = names(startsWith(names,'proposed_') & endsWith(names,'_px'));
if isempty(candidate)
    error('文件缺少 amplitude fusion 的 proposed_*_px 列：%s',csvPath);
end
% 每个 AP-CV 位移结果只有一个方向；若存在多个候选，优先使用首个并记录名称。
displacementName = candidate{1};
time = double(tableValue.time_s(:));
displacement = double(tableValue.(displacementName)(:));
valid = isfinite(time) & isfinite(displacement);
if nnz(valid) < 3
    error('有效位移样本不足 3 个：%s',csvPath);
end
time = time(valid); displacement = displacement(valid);
dt = diff(time);
if any(dt <= 0) || any(abs(dt-median(dt)) > max(1e-9,1e-4*median(dt)))
    error('时间列必须严格递增且近似等间隔：%s',csvPath);
end
% gradient 使用真实时间向量，兼容非整数采样率；不人为平滑或改变原始位移。
acceleration = gradient(gradient(displacement,time),time);
accelerationName = [stem '_acceleration.csv'];
accelerationCsv = fullfile(outputDirectory,accelerationName);
writetable(table(time,acceleration,'VariableNames',{'time_s','acceleration_px_s2'}),accelerationCsv);

axisToken = localAxisToken(displacementName);
waveformPng = fullfile(outputDirectory,[stem '_acceleration_waveform.png']);
waveformFig = fullfile(outputDirectory,[stem '_acceleration_waveform.fig']);
fig = figure('Visible','off','Color','w','Position',[100 100 1100 460]);
plot(time,acceleration,'Color',[0.05 0.20 0.55],'LineWidth',1.0);
grid on; xlabel('Time (s)'); ylabel('Acceleration (pixel/s^2)');
title(sprintf('Amplitude-phase fusion acceleration waveform (%s)',axisToken));
exportgraphics(fig,waveformPng,'Resolution',220,'BackgroundColor','white');
set(fig,'Visible','on'); savefig(fig,waveformFig); set(fig,'Visible','off'); close(fig);

signal = acceleration-mean(acceleration,'omitnan');
n = numel(signal); window = 0.5-0.5*cos(2*pi*(0:n-1)'/max(n-1,1));
nfft = 2^nextpow2(n); spectrum = abs(fft(signal.*window,nfft))/sum(window);
spectrum = spectrum(1:floor(nfft/2)+1);
if numel(spectrum)>2, spectrum(2:end-1)=2*spectrum(2:end-1); end
frequency = (0:numel(spectrum)-1)'*1/median(dt)/nfft;
spectrumPng = fullfile(outputDirectory,[stem '_acceleration_spectrum.png']);
spectrumFig = fullfile(outputDirectory,[stem '_acceleration_spectrum.fig']);
fig = figure('Visible','off','Color','w','Position',[100 100 1000 440]);
plot(frequency,spectrum,'Color',[0.30 0.12 0.55],'LineWidth',1.1);
grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude (pixel/s^2)');
title(sprintf('Amplitude-phase fusion acceleration spectrum (%s)',axisToken));
exportgraphics(fig,spectrumPng,'Resolution',220,'BackgroundColor','white');
set(fig,'Visible','on'); savefig(fig,spectrumFig); set(fig,'Visible','off'); close(fig);

output.csvPath=csvPath; output.accelerationCsv=accelerationCsv;
output.waveformPng=waveformPng; output.waveformFig=waveformFig;
output.spectrumPng=spectrumPng; output.spectrumFig=spectrumFig;
end

function axisToken = localAxisToken(displacementName)
if contains(displacementName,'_x_')
    axisToken = 'X';
elseif contains(displacementName,'_y_')
    axisToken = 'Y';
else
    axisToken = 'unknown';
end
end
