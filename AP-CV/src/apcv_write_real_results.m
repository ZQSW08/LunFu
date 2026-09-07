function apcv_write_real_results(output, outputDirectory, outputName)
%APCV_WRITE_REAL_RESULTS 保存真实视频的表格、MAT、波形、频谱和过程图。
% 真实视频入口不再输出 PDF；波形和频谱同时保存 PNG 与 MATLAB FIG。

time = output.videoInfo.time(:);
result = output.result;
if isfield(output, 'direction')
    direction = apcv_normalize_direction(output.direction);
else
    direction = 'vertical';
end
if strcmpi(direction, 'horizontal')
    axisLetter = 'x';
    axisLabel = 'X displacement';
else
    axisLetter = 'y';
    axisLabel = 'Y displacement';
end

% CSV 列名明确包含 x/y，避免横向和竖向结果混淆。
variableNames = {'time_s', ['coarse_' axisLetter '_px'], ...
    'phase_residual_rad', ['proposed_' axisLetter '_px'], ...
    ['amplitude_only_' axisLetter '_px'], ['vibration_residual_' axisLetter '_px']};
vibrationResidual = localField(result,'vibrationResidualPx',result.proposedPx);
tableValue = table(time, result.coarsePx(:), ...
    result.phaseActive(:, output.model.selectedIndex), result.proposedPx(:), ...
    result.amplitudeOnlyPx(:), vibrationResidual(:), 'VariableNames', variableNames);
if output.physicalScaleProvided
    tableValue.(['proposed_' axisLetter '_mm']) = result.proposedMm(:);
    tableValue.(['amplitude_only_' axisLetter '_mm']) = result.amplitudeOnlyMm(:);
    tableValue.(['vibration_residual_' axisLetter '_mm']) = ...
        localField(result,'vibrationResidualMm',result.proposedMm);
end
if isfield(result,'trackingValid')
    tableValue.tracking_valid=result.trackingValid(:);
    tableValue.(['proposed_' axisLetter '_px_valid_only'])=result.proposedPxValidOnly(:);
end
if isfield(result,'adaptiveLevel')
    tableValue.adaptive_pyramid_level=result.adaptiveLevel(:);
end
writetable(tableValue, fullfile(outputDirectory, [outputName '_displacement.csv']));

% MAT 保存全部配置、视频元数据、模型、结果和真值，便于后续复核。
save(fullfile(outputDirectory, [outputName '_run.mat']), '-struct', 'output', '-v7.3');

% 波形和频谱是正式输出；过程图由同一函数统一生成。
writeWaveformFigure(output, outputDirectory, outputName, time, axisLabel);
writeResidualWaveformFigure(output, outputDirectory, outputName, time, axisLabel);
writeSpectrumFigure(output, outputDirectory, outputName, time, axisLabel);
writeProcessFigure(output, outputDirectory, outputName, axisLabel);
if isfield(output, 'dynamicROI') && output.dynamicROI.enabled
    writeDynamicRoiDiagnostics(output, outputDirectory, outputName, time);
end
end

function writeResidualWaveformFigure(output, outputDirectory, outputName, time, axisLabel)
% 动态 ROI 时单独输出微振动残差，防止总位移的大运动遮住振动波形。
if isfield(output.result,'vibrationResidualPx')
    signal = output.result.vibrationResidualPx(:);
else
    return;
end
if output.physicalScaleProvided
    signal = signal .* output.runConfig.gammaMmPerPixel; unitLabel='mm';
else
    unitLabel='pixel';
end
fig=figure('Visible','off','Color','w','Position',[100 100 1100 420]);
plot(time,signal,'Color',[0.30 0.12 0.55],'LineWidth',1.05); grid on;
xlabel('Time (s)'); ylabel(sprintf('%s (%s)',axisLabel,unitLabel));
title(sprintf('Micro-vibration residual waveform (%s)',axisLabel));
exportgraphics(fig,fullfile(outputDirectory,[outputName '_micro_residual_waveform.png']), ...
    'Resolution',220,'BackgroundColor','white');
close(fig);
end

function writeDynamicRoiDiagnostics(output, outputDirectory, outputName, time)
% 动态 ROI 诊断：保留原始带符号轨迹、低频大运动和实际分析窗口。
% 这些数据用于判断“追踪是否跟上”与“微振动是否仍留给 AP-CV”，不替代位移结果。
t = output.tracking;
n = numel(time);
raw = localPadColumns(t.rawCoarseDisplacement,n);
large = localPadColumns(t.largeMotionContinuous,n);
micro = localPadColumns(t.kltMicroCandidate,n);
roi = localPadMatrix(output.roiTrajectory,n,4);
quality = localPadVector(t.quality,n);
boundary = logical(localPadVector(t.hitBoundary,n));
valid = logical(localPadVector(localField(t,'valid',true(n,1)),n));
redetect = logical(localPadVector(localField(t,'redetectionUsed',false(n,1)),n));
state = strings(n,1);
if isfield(t,'state')
    count=min(n,numel(t.state)); state(1:count)=string(t.state(1:count));
end
tableValue = table(time, raw(:,1), raw(:,2), large(:,1), large(:,2), ...
    micro(:,1), micro(:,2), roi(:,1), roi(:,2), roi(:,3), roi(:,4), quality,valid,redetect,state,boundary, ...
    'VariableNames', {'time_s','raw_x_px','raw_y_px','large_x_px','large_y_px', ...
    'micro_candidate_x_px','micro_candidate_y_px','roi_x','roi_y','roi_width','roi_height', ...
    'tracking_quality','tracking_valid','redetect_used','tracking_state','hit_boundary'});
writetable(tableValue, fullfile(outputDirectory,[outputName '_dynamic_roi.csv']));

fig = figure('Visible','off','Color','w','Position',[100 100 1050 700]);
subplot(2,1,1);
plot(time,raw(:,1),'Color',[0.65 0.65 0.65]); hold on;
plot(time,large(:,1),'Color',[0.05 0.25 0.70],'LineWidth',1.1);
plot(time,raw(:,2),'Color',[0.82 0.45 0.10]);
plot(time,large(:,2),'Color',[0.10 0.55 0.25],'LineWidth',1.1);
grid on; xlabel('Time (s)'); ylabel('Signed displacement (pixel)');
legend('raw x','large x','raw y','large y','Location','best');
title('Dynamic ROI: signed trajectory and crop compensation');
subplot(2,1,2);
yyaxis left; plot(time,quality,'k','LineWidth',0.9); ylim([0 1.05]); ylabel('Tracking quality');
yyaxis right; stairs(time,double(boundary),'r','LineWidth',0.9); ylim([-0.05 1.05]); ylabel('Boundary flag');
xlabel('Time (s)'); grid on; title('Tracking quality and crop boundary status');
exportgraphics(fig,fullfile(outputDirectory,[outputName '_dynamic_roi.png']), ...
    'Resolution',220,'BackgroundColor','white');
close(fig);
end

function value=localField(source,name,defaultValue)
if isstruct(source)&&isfield(source,name)&&~isempty(source.(name)), value=source.(name); else, value=defaultValue; end
end

function matrix = localPadColumns(value,n)
matrix = localPadMatrix(value,n,2);
end

function matrix = localPadMatrix(value,n,columnCount)
value = double(value);
if isempty(value), matrix = nan(n,columnCount); return; end
if size(value,2)<columnCount, value(:,end+1:columnCount) = 0; end
matrix = nan(n,columnCount); count = min(n,size(value,1));
matrix(1:count,:) = value(1:count,1:columnCount);
if count>0 && count<n, matrix(count+1:end,:) = matrix(count,:); end
end

function vector = localPadVector(value,n)
value = value(:); vector = nan(n,1); count = min(n,numel(value));
if count>0
    vector(1:count) = value(1:count);
    if count<n, vector(count+1:end)=vector(count); end
end
end

function writeWaveformFigure(output, outputDirectory, outputName, time, axisLabel)
% 输出融合位移、幅度-only 结果，并在有真值时叠加同单位真值。
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 460]);
if output.physicalScaleProvided
    estimate = output.result.proposedMm(:);
    amplitudeOnly = output.result.amplitudeOnlyMm(:);
    unitLabel = 'mm';
else
    estimate = output.result.proposedPx(:);
    amplitudeOnly = output.result.amplitudeOnlyPx(:);
    unitLabel = 'pixel';
end
plot(time, estimate, '-', 'Color', [0.05 0.20 0.55], 'LineWidth', 1.15); hold on;
plot(time, amplitudeOnly, '--', 'Color', [0.85 0.35 0.05], 'LineWidth', 0.9);
legendEntries = {'Amplitude-phase fusion', 'Amplitude only'};
if isfield(output, 'truth') && output.truth.available
    truth = output.truth.displacement(:);
    % 像素真值在有物理尺度时换算为毫米；毫米真值在无尺度时不会被允许进入流程。
    if strcmpi(output.truth.units, 'pixel') && output.physicalScaleProvided
        truth = output.runConfig.gammaMmPerPixel .* truth;
    end
    truthUnits = lower(char(output.truth.units));
    if strcmpi(output.truth.units, 'pixel') && output.physicalScaleProvided
        truthUnits = 'mm';
    end
    if strcmpi(truthUnits, unitLabel)
        plot(time, truth, ':', 'Color', [0.1 0.55 0.2], 'LineWidth', 1.0);
        legendEntries{end+1} = 'Reference truth'; %#ok<AGROW>
    end
end
grid on; xlabel('Time (s)'); ylabel(sprintf('%s (%s)', axisLabel, unitLabel));
title(sprintf('AP-CV displacement waveform (%s)', axisLabel));
legend(legendEntries, 'Location', 'best');
exportgraphics(fig, fullfile(outputDirectory, [outputName '_waveform.png']), ...
    'Resolution', 220, 'BackgroundColor', 'white');
% 保存前恢复 Visible=on；否则双击 FIG 时会继承 off 状态，看起来像无法打开。
set(fig, 'Visible', 'on');
savefig(fig, fullfile(outputDirectory, [outputName '_waveform.fig']));
set(fig, 'Visible', 'off');
close(fig);
end

function writeSpectrumFigure(output, outputDirectory, outputName, time, axisLabel)
% 对去均值后的融合位移使用 Hann 窗，输出单边幅值频谱。
if output.physicalScaleProvided
    if isfield(output,'dynamicROI') && output.dynamicROI.enabled && isfield(output.result,'apcvResidualPx')
        % 动态 ROI 的全局位移包含 fDSST 宏运动，直接做频谱会淹没微振动；
        % 频谱改用 AP-CV 局部残差，波形图仍保留全局 proposed 曲线。
        signal = double(output.result.apcvResidualPx(:)) .* output.runConfig.gammaMmPerPixel;
    else
        signal = double(output.result.proposedMm(:));
    end
    unitLabel = 'mm';
else
    if isfield(output,'dynamicROI') && output.dynamicROI.enabled && isfield(output.result,'apcvResidualPx')
        signal = double(output.result.apcvResidualPx(:));
    else
        signal = double(output.result.proposedPx(:));
    end
    unitLabel = 'pixel';
end
finiteMask = isfinite(signal) & isfinite(time);
signal = signal(finiteMask);
if numel(signal) >= 3
    signal = signal - mean(signal);
    n = numel(signal);
    window = 0.5 - 0.5*cos(2*pi*(0:n-1)'/max(n-1,1));
    nfft = 2^nextpow2(n);
    spectrum = abs(fft(signal .* window, nfft)) / sum(window);
    spectrum = spectrum(1:floor(nfft/2)+1);
    if numel(spectrum) > 2
        spectrum(2:end-1) = 2*spectrum(2:end-1);
    end
    fs = output.videoInfo.processingFps;
    frequency = (0:numel(spectrum)-1)' * fs / nfft;
else
    frequency = 0;
    spectrum = 0;
end
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 440]);
plot(frequency, spectrum, 'Color', [0.30 0.12 0.55], 'LineWidth', 1.1);
grid on; xlabel('Frequency (Hz)'); ylabel(sprintf('Amplitude (%s)', unitLabel));
if isfield(output,'dynamicROI') && output.dynamicROI.enabled && isfield(output.result,'apcvResidualPx')
    title(sprintf('Micro-vibration residual spectrum (%s; detrended Hann window)', axisLabel));
else
    title(sprintf('Single-sided spectrum (%s; detrended Hann window)', axisLabel));
end
exportgraphics(fig, fullfile(outputDirectory, [outputName '_spectrum.png']), ...
    'Resolution', 220, 'BackgroundColor', 'white');
% 同上，确保 MATLAB 双击打开后图窗可见。
set(fig, 'Visible', 'on');
savefig(fig, fullfile(outputDirectory, [outputName '_spectrum.fig']));
set(fig, 'Visible', 'off');
close(fig);
end

function writeProcessFigure(output, outputDirectory, outputName, axisLabel)
% 汇总首帧、对齐帧、相位残差、主动像素、层级曲线和标定响应等中间证据。
model = output.model;
selectedIndex = model.selectedIndex;
cache = model.calibrationCache;
n = size(cache.alignedFrames, 3);
frameIndex = max(1, min(n, round(n/2)));
phaseMap = cache.phaseDifference{selectedIndex}(:, :, frameIndex);
activeMask = model.levels(selectedIndex).activeMask;
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1250 760]);

subplot(2,3,1);
imagesc(model.referenceImage); axis image off; colormap gray; title('Reference frame');
subplot(2,3,2);
imagesc(cache.alignedFrames(:, :, frameIndex)); axis image off; colormap gray;
title(sprintf('Aligned frame %d', frameIndex));
subplot(2,3,3);
imagesc(phaseMap); axis image off; colorbar; title('Phase residual map');
subplot(2,3,4);
imagesc(activeMask); axis image off; colorbar; title('Active-pixel mask');
subplot(2,3,5);
plot(output.result.byLevelPx, 'LineWidth', 0.85); grid on;
xlabel('Frame'); ylabel(sprintf('%s (pixel)', axisLabel));
title('Per-level displacement');
legend(compose('Level %d', [model.levels.level]), 'Location', 'best');
subplot(2,3,6);
plot(model.calibrationSampleIndices, model.levels(selectedIndex).calibrationResponse, ...
    'o-', 'LineWidth', 0.9, 'MarkerSize', 3); grid on;
xlabel('Calibration frame'); ylabel('\Delta\phi (rad)');
title(sprintf('Calibration response (level %d)', model.selectedLevel));

sgtitle(sprintf('AP-CV intermediate processing (%s)', axisLabel));
exportgraphics(fig, fullfile(outputDirectory, [outputName '_process.png']), ...
    'Resolution', 220, 'BackgroundColor', 'white');
close(fig);
end
