% RUN_REAL_VIDEO 使用 SPOF 处理一段真实视频。
% 本脚本只负责输入、ROI、帧率、输出和参考信号编排；SPOF 公式位于 src/。
% 论文明确：Gabor 相位光流 -> 结构置信度 -> GMM-EM 异常修复 -> ROI 积分。
% 实现推断：真实数据参数、边界处理、参考信号同步和加速度双积分需由用户配置。

close all; clearvars; clc;
scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot, 'src'));

%% 1. 用户配置区：真实运行前只需修改这里
config = struct();
config.videoPath = 'C:\0819\4-25mvpp-motion.avi';    % 例如：'D:\data\exciter.avi'
config.outputDirectory = 'D:\LunFu\SPOF\outputs\0819\4-25mvpp-motion';
config.outputName = '4-25mvpp-motion';
config.roi = [];                               % [x y width height]；[] 时首帧交互选择
config.maxFrames = Inf;                         % Inf 表示读取全部可用帧
config.fpsOverride = 100;                        % [] 使用视频元数据帧率
config.scaleMmPerPixel = [];                    % 未标定必须为空；标定后填写 mm/Px
config.measurementDirection = 'x';           % 'x'、'y' 或 'auto'
config.useNominalSpatialFrequency = true;       % Gabor名义载频；false可核验式(8)-(9)局部梯度
config.minAmplitude = 1e-4;                     % 论文基线；低纹理视频可再按ROI调节
config.integrationConfidenceThreshold = 0.5;   % 真实视频增强；设为0即论文式(23)
config.saveFullResult = false;                  % 防止把 HD 视频的全部复响应保存成超大 MAT
config.saveInputFrame = true;
config.saveProcessFigure = true;
config.saveRoiVideo = true;                     % 输出裁剪后的 ROI 视频（AVI）
config.roiVideoProfile = 'Uncompressed AVI';    % 兼容 MATLAB/系统播放器，避免 MJPEG 解码依赖
config.writeSignalCsv = true;

% 可选参考信号：CSV 第一列时间（秒），第二列信号值。
% signalType='displacement' 时直接比较；signalType='acceleration' 时先双积分。
config.reference.path = '';
config.reference.signalType = 'displacement';  % 'displacement' 或 'acceleration'
config.reference.units = 'Px';                 % 'mm' 或 'Px'；mm 需要先完成标定
config.reference.timeOffsetSeconds = 0;        % 参考信号相对视频时间的手动偏移

%% 2. 检查输入并读取第一帧
if isempty(config.videoPath) || ~isfile(config.videoPath)
    error('SPOF:InputVideo', '请先在顶部填写存在的 config.videoPath。');
end

reader = VideoReader(config.videoPath);
videoFps = reader.FrameRate;
processingFps = videoFps;
if ~isempty(config.fpsOverride)
    processingFps = config.fpsOverride;
end
if ~isfinite(processingFps) || processingFps <= 0
    error('SPOF:FrameRate', '视频帧率无效，请填写 config.fpsOverride。');
end

if ~hasFrame(reader)
    error('SPOF:EmptyVideo', '视频中没有可读取的帧。');
end
firstFrame = readFrame(reader);
firstGray = frame_to_gray_double(firstFrame);

%% 3. ROI 选择：确认成功后才创建本次输出目录
[roiRect, cancelled] = select_spof_roi(firstGray, config.roi, ...
    'SPOF ROI（用于相位光流和位移测量）');
if cancelled
    fprintf('ROI 选择已取消，未清理或修改上一轮输出。\n');
    return;
end
roiRect = clamp_rect(roiRect, size(firstGray));
if roiRect(3) < 16 || roiRect(4) < 16
    error('SPOF:SmallROI', 'ROI 太小，至少需要 16x16 像素。');
end

% 输出目录是用户配置的固定目录；每次运行覆盖本次入口生成的固定文件名，
% 不再创建时间戳子目录，便于连续调参和比较结果。
runDirectory = config.outputDirectory;
if ~exist(runDirectory, 'dir'), mkdir(runDirectory); end
clear_spof_outputs(runDirectory);

%% 4. 读取、裁剪和验证实际帧数
reader = VideoReader(config.videoPath);
if isfinite(config.maxFrames)
    frameCapacity = max(3, ceil(config.maxFrames));
else
    frameCapacity = max(3, ceil(reader.Duration * processingFps) + 1);
end
if ~isfinite(frameCapacity)
    error('SPOF:FrameCountUnknown', '无法确定视频总时长，请设置有限的 config.maxFrames。');
end
frames = cell(1, frameCapacity);
frameCount = 0;
while hasFrame(reader) && frameCount < config.maxFrames
    frame = frame_to_gray_double(readFrame(reader));
    frame = crop_frame(frame, roiRect);
    frameCount = frameCount + 1;
    frames{frameCount} = frame;
end
if frameCount < 3
    error('SPOF:TooFewFrames', '可处理帧数不足 3 帧，无法计算相位时间导数。');
end
frames = frames(1:frameCount);
video = cat(3, frames{:});
analysisRoi = true(size(video, 1), size(video, 2));

if config.saveRoiVideo
    write_roi_video(video, processingFps, fullfile(runDirectory, '04_roi_video.avi'), ...
        config.roiVideoProfile);
end

%% 5. 调用 SPOF 主算法
cfg = spof_default_config();
cfg.method = 'SPOF';
cfg.scaleMmPerPixel = config.scaleMmPerPixel;
cfg.useNominalSpatialFrequency = config.useNominalSpatialFrequency;
cfg.minAmplitude = config.minAmplitude;
cfg.integrationConfidenceThreshold = config.integrationConfidenceThreshold;
result = spof_measure(video, processingFps, analysisRoi, cfg);
[estimatePx, estimatePhysical, selectedDirection] = select_measurement_signal(...
    result.signal, config.measurementDirection, config.scaleMmPerPixel);

%% 6. 保存运行配置、输入信息和算法结果
runInfo = struct();
runInfo.videoPath = config.videoPath;
runInfo.videoFps = videoFps;
runInfo.processingFps = processingFps;
runInfo.requestedMaxFrames = config.maxFrames;
runInfo.actualFrameCount = frameCount;
runInfo.originalFrameSize = [size(firstGray, 2), size(firstGray, 1)];
runInfo.roiRectXYWH = roiRect;
runInfo.scaleMmPerPixel = config.scaleMmPerPixel;
runInfo.calibrated = ~isempty(config.scaleMmPerPixel);
runInfo.measurementDirectionRequested = config.measurementDirection;
runInfo.measurementDirectionSelected = selectedDirection;
runInfo.spatialFrequencyMode = ternary(config.useNominalSpatialFrequency, ...
    'nominal-gabor-frequency', 'local-phase-gradient');
runInfo.meanConfidence = mean(double(result.confidence(:)), 'omitnan');
runInfo.abnormalRate = mean(double(result.abnormalMask(:)), 'omitnan');
runInfo.selectedDisplacementStdPx = std(double(estimatePx), 'omitnan');
runInfo.roiVideoFile = '';
if config.saveRoiVideo
    runInfo.roiVideoFile = fullfile(runDirectory, '04_roi_video.avi');
    runInfo.roiVideoFrameSize = [size(video, 2), size(video, 1)];
end
runInfo.runDirectory = runDirectory;
save(fullfile(runDirectory, 'run_config.mat'), 'config', 'cfg', 'runInfo');
jsonConfig = config;
if isinf(jsonConfig.maxFrames), jsonConfig.maxFrames = -1; end
jsonRunInfo = runInfo;
if isinf(jsonRunInfo.requestedMaxFrames), jsonRunInfo.requestedMaxFrames = -1; end
write_json_if_available(fullfile(runDirectory, 'run_config.json'), struct(...
    'config', jsonConfig, 'algorithm', cfg, 'runInfo', jsonRunInfo));

if config.saveInputFrame
    fig = figure('Visible','off','Color','w');
    imagesc(video(:,:,1)); axis image off; colormap gray;
    title('SPOF input ROI');
    save_figure_pair(fig, fullfile(runDirectory, '01_input_roi')); close(fig);
end

if config.saveProcessFigure
    save_spof_process_figure(video, result, runDirectory);
end

time = result.signal.time;
if isempty(result.signal.xMm)
    xMm = nan(size(time)); yMm = nan(size(time));
else
    xMm = result.signal.xMm; yMm = result.signal.yMm;
end
if isempty(estimatePhysical)
    estimatePhysicalForTable = nan(size(time));
else
    estimatePhysicalForTable = estimatePhysical;
end
signalTable = table(time, result.signal.vx, result.signal.vy, result.signal.x, ...
    result.signal.y, xMm, yMm, estimatePx, estimatePhysicalForTable, ...
    'VariableNames', {'time_s','vx_Px_s','vy_Px_s','disp_x_Px', ...
    'disp_y_Px','disp_x_mm','disp_y_mm','selected_disp_Px','selected_disp_physical'});
if config.writeSignalCsv
    writetable(signalTable, fullfile(runDirectory, '05_spof_signal.csv'));
end
resultToSave = result;
if ~config.saveFullResult
    % 真实视频的完整三维复响应/相位/光流会使 MAT 文件从 MB 膨胀到
    % 数百 MB；过程图已经保存，因此默认只保留信号、GMM 模型和代表帧。
    processFrame = min(10, size(video, 3));
    resultToSave = struct('method', result.method, 'signal', result.signal, ...
        'gmmX', result.gmmX, 'gmmY', result.gmmY, ...
        'confidenceFrame', result.confidence(:,:,processFrame), ...
        'posteriorAbnormalFrame', result.posteriorAbnormal(:,:,processFrame), ...
        'abnormalMaskFrame', result.abnormalMask(:,:,processFrame), ...
        'finalFlowFrame', struct('vx', result.finalFlow.vx(:,:,processFrame), ...
        'vy', result.finalFlow.vy(:,:,processFrame)));
end
result = resultToSave;
if config.saveFullResult
    save(fullfile(runDirectory, '06_spof_result.mat'), 'result', 'runInfo', '-v7.3');
else
    save(fullfile(runDirectory, '06_spof_result.mat'), 'result', 'runInfo');
end

fig = figure('Visible','off','Color','w');
plot(time, estimatePx, 'r', 'LineWidth', 1.1); hold on;
grid on; xlabel('Time (s)');
if isempty(config.scaleMmPerPixel), ylabel('Displacement (Px)');
else, ylabel('Displacement (mm)'); end
legend(['SPOF ', selectedDirection], 'Location','best');
title(sprintf('SPOF real-video displacement (%s, %s)', upper(selectedDirection), ...
    ternary(isempty(config.scaleMmPerPixel), 'pixel unit', 'calibrated unit')));
save_figure_pair(fig, fullfile(runDirectory, '07_spof_displacement')); close(fig);

fig = figure('Visible','off','Color','w');
[frequency, amplitude] = one_sided_spectrum(estimatePx, processingFps);
plot(frequency, amplitude, 'r', 'LineWidth', 1.1); grid on;
xlabel('Frequency (Hz)'); ylabel('Amplitude (Px)');
title(sprintf('SPOF displacement spectrum (%s)', upper(selectedDirection)));
save_figure_pair(fig, fullfile(runDirectory, '10_spof_spectrum')); close(fig);

%% 7. 可选参考信号对齐和评价；没有参考信号时只保存视频测量结果
if ~isempty(config.reference.path)
    [referenceTime, referenceSignal] = read_reference_signal(config.reference);
    referenceSignal = interp1(referenceTime + config.reference.timeOffsetSeconds, ...
        referenceSignal, time, 'linear', NaN);
    if strcmpi(config.reference.units, 'mm')
        if isempty(estimatePhysical)
            error('SPOF:ReferenceCalibration', ...
                '参考信号单位为 mm，但 config.scaleMmPerPixel 为空；请先完成像素-毫米标定。');
        end
        estimatedSignal = estimatePhysical;
    else
        estimatedSignal = estimatePx;
    end
    metrics = spof_metrics(referenceSignal, estimatedSignal);
    writetable(table(time, referenceSignal, estimatedSignal, ...
        'VariableNames', {'time_s','reference','SPOF_estimate'}), ...
        fullfile(runDirectory, '08_reference_comparison.csv'));
    save(fullfile(runDirectory, '08_reference_metrics.mat'), 'metrics', ...
        'referenceTime', 'referenceSignal', 'estimatedSignal');
    fig = figure('Visible','off','Color','w');
    plot(time, referenceSignal, 'k--', 'LineWidth', 1.1); hold on;
    plot(time, estimatedSignal, 'r', 'LineWidth', 1.0); grid on;
    xlabel('Time (s)'); ylabel(['Displacement (', config.reference.units, ')']);
    legend('Reference','SPOF','Location','best'); title('SPOF reference comparison');
    save_figure_pair(fig, fullfile(runDirectory, '09_reference_comparison')); close(fig);
    fprintf('参考信号对比：MAE=%.6g, RMSE=%.6g, PCC=%.6g\n', ...
        metrics.mae, metrics.rmse, metrics.pcc);
else
    fprintf('SPOF 真实视频处理完成；未提供参考信号，因此未计算 MAE/RMSE/PCC。\n');
end

fprintf('实际帧数：%d；视频帧率：%.6g Hz；处理帧率：%.6g Hz\n', ...
    frameCount, videoFps, processingFps);
fprintf('本次结果目录：%s\n', runDirectory);

function gray = frame_to_gray_double(frame)
% 将 uint8/uint16/浮点彩色帧统一转换为 [0,1] 灰度帧。
wasInteger = isinteger(frame);
className = class(frame);
if ndims(frame) == 3
    frame = 0.2989*double(frame(:,:,1)) + 0.5870*double(frame(:,:,2)) ...
        + 0.1140*double(frame(:,:,3));
else
    frame = double(frame);
end
if wasInteger
    gray = frame / double(intmax(className));
else
    scale = max(frame(:));
    if scale > 1, gray = frame / scale; else, gray = frame; end
end
gray = min(max(gray, 0), 1);
end

function frame = crop_frame(frame, rect)
x1 = rect(1); y1 = rect(2); x2 = x1 + rect(3) - 1; y2 = y1 + rect(4) - 1;
frame = frame(y1:y2, x1:x2);
end

function rect = clamp_rect(rect, imageSize)
imageHeight = imageSize(1); imageWidth = imageSize(2);
rect = round(rect(:).');
rect(1) = max(1, min(rect(1), imageWidth));
rect(2) = max(1, min(rect(2), imageHeight));
rect(3) = max(1, min(rect(3), imageWidth - rect(1) + 1));
rect(4) = max(1, min(rect(4), imageHeight - rect(2) + 1));
end

function [rect, cancelled] = select_spof_roi(firstFrame, preset, windowTitle)
cancelled = false;
if ~isempty(preset)
    rect = clamp_rect(preset, size(firstFrame));
    return;
end
if isempty(which('drawrectangle'))
    error('SPOF:InteractiveROIUnavailable', ...
        '未检测到 drawrectangle，请填写 config.roi=[x y width height]。');
end

fig = figure('Name', windowTitle, 'NumberTitle','off', 'Color','w', ...
    'MenuBar','none', 'ToolBar','figure', 'CloseRequestFcn', @cancel_callback, ...
    'KeyPressFcn', @key_press_callback);
imagesc(firstFrame); axis image off; colormap gray;
title({'拖动矩形选择 SPOF 处理区域', ...
    '双击 ROI 或按 Enter 确认；按 Esc 取消并退出'});
handle = drawrectangle('Color','r');
setappdata(fig, 'cancelled', false);
setappdata(fig, 'confirmed', false);
roiListener = addlistener(handle, 'ROIClicked', @roi_clicked_callback); %#ok<NASGU>
figure(fig);
uiwait(fig);
if ~ishandle(fig)
    rect = [];
    cancelled = true;
    return;
end
cancelled = getappdata(fig, 'cancelled');
confirmed = getappdata(fig, 'confirmed');
if cancelled || ~confirmed || ~ishandle(handle)
    rect = [];
    cancelled = true;
else
    rect = clamp_rect(handle.Position, size(firstFrame));
end
delete(fig);

    function confirm_callback(~, ~)
        if isgraphics(fig)
            setappdata(fig, 'confirmed', true);
            uiresume(fig);
        end
    end
    function cancel_callback(~, ~)
        if isgraphics(fig)
            setappdata(fig, 'cancelled', true);
            uiresume(fig);
        end
    end
    function roi_clicked_callback(~, event)
        if strcmpi(event.SelectionType, 'double')
            confirm_callback([], []);
        end
    end
    function key_press_callback(~, event)
        if any(strcmpi(event.Key, {'return','enter'}))
            confirm_callback([], []);
        elseif strcmpi(event.Key, 'escape')
            cancel_callback([], []);
        end
    end
end

function [t, signal] = read_reference_signal(referenceConfig)
if ~isfile(referenceConfig.path)
    error('SPOF:ReferenceFile', '参考信号文件不存在：%s', referenceConfig.path);
end
raw = readmatrix(referenceConfig.path);
if size(raw,2) < 2
    error('SPOF:ReferenceFormat', '参考 CSV 至少需要两列：时间和信号。');
end
t = raw(:,1); signal = raw(:,2);
valid = isfinite(t) & isfinite(signal);
t = t(valid); signal = signal(valid);
if numel(t) < 3 || any(diff(t) <= 0)
    error('SPOF:ReferenceTime', '参考信号时间列必须严格递增且至少有 3 个有效点。');
end
if strcmpi(referenceConfig.signalType, 'acceleration')
    % 加速度计到位移需要双积分；零频漂移会显著影响结果，因此去除线性趋势。
    velocity = cumtrapz(t, signal);
    signal = cumtrapz(t, velocity);
    trend = polyval(polyfit(t, signal, 1), t);
    signal = signal - trend;
elseif ~strcmpi(referenceConfig.signalType, 'displacement')
    error('SPOF:ReferenceType', 'reference.signalType 只能是 displacement 或 acceleration。');
end
end

function save_spof_process_figure(video, result, runDirectory)
frameIndex = min(10, size(video,3));
fig = figure('Visible','off','Color','w','Position',[100 100 1250 720]);
set(fig, 'DefaultAxesFontName','Times New Roman', 'DefaultTextFontName','Times New Roman');
subplot(2,4,1); imagesc(video(:,:,frameIndex)); axis image off; title('(a) Input ROI'); colormap gray;
subplot(2,4,2); imagesc(abs(result.flow.responses{1}(:,:,frameIndex))); axis image off; title('(b) Gabor amplitude'); colorbar;
subplot(2,4,3); imagesc(result.flow.phases{1}(:,:,frameIndex)); axis image off; title('(c) Unwrapped phase'); colorbar;
subplot(2,4,4); imagesc(result.confidence(:,:,frameIndex), [0 1]); axis image off; title('(d) Confidence C'); colorbar;
subplot(2,4,5); imagesc(result.posteriorAbnormal(:,:,frameIndex), [0 1]); axis image off; title('(e) Abnormal posterior'); colorbar;
subplot(2,4,6); imagesc(result.abnormalMask(:,:,frameIndex)); axis image off; title('(f) Abnormal mask'); colorbar;
subplot(2,4,7); imagesc(result.finalFlow.vx(:,:,frameIndex)); axis image off; title('(g) Refined v_x (Px/s)'); colorbar;
subplot(2,4,8); imagesc(result.finalFlow.vy(:,:,frameIndex)); axis image off; title('(h) Refined v_y (Px/s)'); colorbar;
sgtitle('SPOF real-video intermediate outputs');
save_figure_pair(fig, fullfile(runDirectory, '02_spof_process')); close(fig);
end

function [selectedPx, selectedPhysical, direction] = select_measurement_signal(signal, requested, scale)
if strcmpi(requested, 'x') || strcmpi(requested, 'y')
    direction = lower(requested);
else
    x = signal.x - mean(signal.x, 'omitnan');
    y = signal.y - mean(signal.y, 'omitnan');
    if std(x, 'omitnan') >= std(y, 'omitnan'), direction = 'x'; else, direction = 'y'; end
end
if direction == 'x'
    selectedPx = signal.x;
    if isempty(scale), selectedPhysical = []; else, selectedPhysical = signal.xMm; end
else
    selectedPx = signal.y;
    if isempty(scale), selectedPhysical = []; else, selectedPhysical = signal.yMm; end
end
end

function [frequency, amplitude] = one_sided_spectrum(signal, fs)
signal = double(signal(:));
signal = signal - mean(signal, 'omitnan');
signal(~isfinite(signal)) = 0;
n = numel(signal); nfft = 2^nextpow2(max(n, 2));
fourier = abs(fft(signal, nfft)) / n;
count = floor(nfft/2) + 1;
amplitude = fourier(1:count);
if count > 2, amplitude(2:end-1) = 2 * amplitude(2:end-1); end
frequency = (0:count-1)' * fs / nfft;
end

function clear_spof_outputs(runDirectory)
names = {'01_input_roi.png','01_input_roi.fig','02_spof_process.png','02_spof_process.fig', ...
    '04_roi_video.avi','05_spof_signal.csv','06_spof_result.mat','07_spof_displacement.png', ...
    '07_spof_displacement.fig','08_reference_comparison.csv','08_reference_metrics.mat', ...
    '09_reference_comparison.png','09_reference_comparison.fig','10_spof_spectrum.png', ...
    '10_spof_spectrum.fig','run_config.mat','run_config.json'};
for i = 1:numel(names)
    filename = fullfile(runDirectory, names{i});
    if isfile(filename), delete(filename); end
end
end

function save_figure_pair(fig, baseName)
saveas(fig, [baseName, '.png']);
% 保存时强制记录 Visible='on'。否则脚本中的隐藏图窗会被 FIG 文件
% 以不可见状态保存，MATLAB 双击打开后实际已载入但用户看不到窗口。
oldVisible = fig.Visible;
fig.Visible = 'on';
savefig(fig, [baseName, '.fig']);
fig.Visible = oldVisible;
end

function write_roi_video(video, frameRate, filename, profile)
writer = VideoWriter(filename, profile);
writer.FrameRate = frameRate;
open(writer);
for k = 1:size(video, 3)
    frame = uint8(round(255 * min(max(video(:, :, k), 0), 1)));
    writeVideo(writer, frame);
end
close(writer);
end

function out = ternary(condition, trueValue, falseValue)
if condition, out = trueValue; else, out = falseValue; end
end

function write_json_if_available(filename, value)
try
    fid = fopen(filename, 'w');
    fprintf(fid, '%s', jsonencode(value));
    fclose(fid);
catch err
    warning('SPOF:JsonWrite', 'JSON 配置保存失败，但 MAT 配置已保存：%s', err.message);
end
end
