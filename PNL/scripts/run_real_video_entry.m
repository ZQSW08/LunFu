function out = run_real_video_entry(videoPathOrConfig, varargin)
%RUN_REAL_VIDEO_ENTRY PNL 真实视频入口：单目优先，同时兼容双目。
%
% 单目调用：
%   out = run_real_video_entry('D:\data\video.avi', ...
%       'Mode', 'mono', 'Roi', [401 251 256 256], 'MaxFrames', 400);
%
% 双目调用：
%   out = run_real_video_entry('D:\data\left.avi', ...
%       'RightVideoPath', 'D:\data\right.avi', ...
%       'CalibrationFile', 'D:\data\calibration.mat', ...
%       'Roi', [401 251 256 256], 'MaxFrames', 400);
%
% 也可以传入一个顶部集中配置的 struct，便于配合 run_real_video.m 使用：
%   config.videoPath = 'D:\data\video.avi';
%   config.mode = 'mono';
%   config.roi = [401 251 256 256];
%   config.analysisDirection = 'both';  % mono: x=水平/u，y=垂直/v，也可选 'x' 或 'y'
%   config.outputDirectory = 'D:\LunFu\PNL\outputs\real\case01';
%   out = run_real_video_entry(config);
%
% 入口只负责编排输入、处理和输出；论文核心实现位于 src/。单目结果只
% 输出二维像素位移和 PNL，不在缺少双目几何时伪造三维位移或 RMSE。

config = parse_entry_config(videoPathOrConfig, varargin{:});
config = validate_entry_config(config);

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'src'));

if strcmp(config.mode, 'mono')
    [frames, video] = read_video_sequence(config.videoPath, config);
    cfg = make_runtime_config(config, video, size(frames));
    methods = run_mono_methods(frames, cfg, config);
    primaryName = config.filter;
    primary = methods.(primaryName);
    out = build_mono_output(config, video, primary, methods, cfg);
    out.outputDirectory = prepare_output_directory(config.outputDirectory, projectRoot);
    plot_real_outputs(out, frames, []);
    out.roiVideo = write_roi_video(frames, video.frameRate, ...
        fullfile(out.outputDirectory, 'real_roi_video.avi'));
else
    leftConfig = config;
    rightConfig = config;
    if config.frameOffset >= 0
        rightConfig.startFrame = config.startFrame + config.frameOffset;
    else
        leftConfig.startFrame = config.startFrame - config.frameOffset;
    end
    [leftFrames, leftVideo] = read_video_sequence(config.videoPath, leftConfig);
    [rightFrames, rightVideo] = read_video_sequence(rightConfig.rightVideoPath, rightConfig);
    if abs(leftVideo.frameRate - rightVideo.frameRate) > 0.5
        warning('左右视频帧率差异为 %.4g fps，请确认同步方式。', ...
            abs(leftVideo.frameRate - rightVideo.frameRate));
    end
    nFrames = min(size(leftFrames, 3), size(rightFrames, 3));
    if nFrames < 2
        error('同步读取后的左右视频有效帧数少于 2。');
    end
    leftFrames = leftFrames(:, :, 1:nFrames);
    rightFrames = rightFrames(:, :, 1:nFrames);
    leftVideo.frames = nFrames;
    rightVideo.frames = nFrames;
    leftVideo.duration = (nFrames - 1) / leftVideo.frameRate;
    rightVideo.duration = (nFrames - 1) / rightVideo.frameRate;
    cfg = make_runtime_config(config, leftVideo, size(leftFrames));
    initialPoints = resolve_stereo_initial_points(config, leftVideo, rightVideo, leftFrames, rightFrames);
    methods = run_stereo_methods(leftFrames, rightFrames, cfg, config, initialPoints);
    if isfield(methods, 'geometry')
        primaryName = 'geometry';
    else
        primaryName = config.filter;
    end
    primary = methods.(primaryName);
    out = build_stereo_output(config, leftVideo, rightVideo, primary, methods, cfg, initialPoints);
    out.outputDirectory = prepare_output_directory(config.outputDirectory, projectRoot);
    plot_real_outputs(out, leftFrames, rightFrames);
    out.roiVideo = struct();
    out.roiVideo.left = write_roi_video(leftFrames, leftVideo.frameRate, ...
        fullfile(out.outputDirectory, 'real_roi_left.avi'));
    out.roiVideo.right = write_roi_video(rightFrames, rightVideo.frameRate, ...
        fullfile(out.outputDirectory, 'real_roi_right.avi'));
end

save(fullfile(out.outputDirectory, 'real_video_results.mat'), 'out', '-v7.3');
write_real_metadata(out);
fprintf('Real %s results written to %s\n', out.mode, out.outputDirectory);
end

function config = parse_entry_config(videoPathOrConfig, varargin)
% 将“顶部配置 struct”和兼容的 name-value 调用统一为清晰的内部配置。
if isstruct(videoPathOrConfig)
    config = videoPathOrConfig;
    config = fill_config_defaults(config);
    if ~isempty(varargin)
        config = apply_name_value_config(config, varargin{:});
    end
    config = normalize_config(config);
    return;
end
if ~(ischar(videoPathOrConfig) || isstring(videoPathOrConfig))
    error('第一个参数必须是单目视频路径或配置 struct。');
end

config = fill_config_defaults(struct());
config.videoPath = char(videoPathOrConfig);
knownNames = {'Mode', 'RightVideoPath', 'CalibrationFile', 'Roi', ...
    'InitialPoint', 'InitialPoints', 'FrameOffset', 'MaxFrames', ...
    'StartFrame', 'FpsOverride', 'OutputDirectory', 'OutputDir', ...
    'Filter', 'RunGeneric', 'WorldScale', 'MemoryBudgetGB', 'AnalysisDirection', ...
    'Direction', 'LocalRotation', ...
    'LocalOrigin', 'KeepFlowFields'};
% 兼容此前的 run_real_video_entry(leftVideo, rightVideo, ...) 调用。
if ~isempty(varargin) && is_text_scalar(varargin{1}) && ...
        ~any(strcmpi(char(varargin{1}), knownNames))
    config.rightVideoPath = char(varargin{1});
    varargin(1) = [];
end
config = apply_name_value_config(config, varargin{:});
config = normalize_config(config);
end

function config = fill_config_defaults(config)
defaults = struct();
defaults.videoPath = '';
defaults.rightVideoPath = '';
defaults.mode = 'auto';
defaults.calibrationFile = '';
defaults.roi = [];
defaults.initialPoint = [];
defaults.initialPoints = [];
defaults.frameOffset = 0;
defaults.maxFrames = 400;
defaults.startFrame = 1;
defaults.fpsOverride = [];
defaults.outputDirectory = '';
defaults.filter = 'geometry';
defaults.runGeneric = true;
defaults.analysisDirection = 'both';
defaults.worldScale = 1;
defaults.memoryBudgetGB = 2;
defaults.localRotation = eye(3);
defaults.localOrigin = [];
defaults.keepFlowFields = false;
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(config, names{k}) || isempty(config.(names{k}))
        config.(names{k}) = defaults.(names{k});
    end
end
end

function config = apply_name_value_config(config, varargin)
ip = inputParser;
ip.KeepUnmatched = false;
ip.addParameter('Mode', config.mode, @(x) ischar(x) || isstring(x));
ip.addParameter('RightVideoPath', config.rightVideoPath, @(x) ischar(x) || isstring(x));
ip.addParameter('CalibrationFile', config.calibrationFile, @(x) ischar(x) || isstring(x));
ip.addParameter('Roi', config.roi, @(x) isempty(x) || (isnumeric(x) && numel(x) == 4));
ip.addParameter('InitialPoint', config.initialPoint, @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
ip.addParameter('InitialPoints', config.initialPoints, @(x) isempty(x) || (isnumeric(x) && isequal(size(x), [2, 2])));
ip.addParameter('FrameOffset', config.frameOffset, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x == fix(x));
ip.addParameter('MaxFrames', config.maxFrames, @(x) isnumeric(x) && isscalar(x) && (isinf(x) || (isfinite(x) && x >= 2 && x == fix(x))));
ip.addParameter('StartFrame', config.startFrame, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1 && x == fix(x));
ip.addParameter('FpsOverride', config.fpsOverride, @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x) && x > 0));
ip.addParameter('OutputDirectory', config.outputDirectory, @(x) ischar(x) || isstring(x));
ip.addParameter('OutputDir', '', @(x) ischar(x) || isstring(x));
ip.addParameter('Filter', config.filter, @(x) ischar(x) || isstring(x));
ip.addParameter('RunGeneric', config.runGeneric, @(x) islogical(x) && isscalar(x));
ip.addParameter('AnalysisDirection', config.analysisDirection, @(x) ischar(x) || isstring(x));
ip.addParameter('Direction', '', @(x) ischar(x) || isstring(x));
ip.addParameter('WorldScale', config.worldScale, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
ip.addParameter('MemoryBudgetGB', config.memoryBudgetGB, @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
ip.addParameter('LocalRotation', config.localRotation, @(x) isnumeric(x) && isequal(size(x), [3, 3]));
ip.addParameter('LocalOrigin', config.localOrigin, @(x) isempty(x) || (isnumeric(x) && numel(x) == 3));
ip.addParameter('KeepFlowFields', config.keepFlowFields, @(x) islogical(x) && isscalar(x));
ip.parse(varargin{:});
v = ip.Results;
config.mode = char(v.Mode);
config.rightVideoPath = char(v.RightVideoPath);
config.calibrationFile = char(v.CalibrationFile);
config.roi = v.Roi;
config.initialPoint = v.InitialPoint;
config.initialPoints = v.InitialPoints;
config.frameOffset = v.FrameOffset;
config.maxFrames = v.MaxFrames;
config.startFrame = v.StartFrame;
config.fpsOverride = v.FpsOverride;
config.outputDirectory = char(v.OutputDirectory);
if ~isempty(v.OutputDir)
    config.outputDirectory = char(v.OutputDir);
end
config.filter = char(v.Filter);
config.runGeneric = v.RunGeneric;
config.analysisDirection = char(v.AnalysisDirection);
if ~isempty(v.Direction)
    config.analysisDirection = char(v.Direction);
end
config.worldScale = v.WorldScale;
config.memoryBudgetGB = v.MemoryBudgetGB;
config.localRotation = v.LocalRotation;
config.localOrigin = v.LocalOrigin;
config.keepFlowFields = v.KeepFlowFields;
end

function config = normalize_config(config)
config.mode = lower(char(config.mode));
config.filter = lower(char(config.filter));
config.videoPath = char(config.videoPath);
config.rightVideoPath = char(config.rightVideoPath);
config.calibrationFile = char(config.calibrationFile);
config.outputDirectory = char(config.outputDirectory);
end

function config = validate_entry_config(config)
config = normalize_config(config);
if ~isfile(config.videoPath)
    error('主视频不存在：%s', config.videoPath);
end
if strcmp(config.mode, 'auto')
    if isempty(config.rightVideoPath)
        config.mode = 'mono';
    else
        config.mode = 'stereo';
    end
end
if ~ismember(config.mode, {'mono', 'stereo'})
    error('Mode 只能是 mono、stereo 或 auto。');
end
if strcmp(config.mode, 'stereo')
    if isempty(config.rightVideoPath) || ~isfile(config.rightVideoPath)
        error('双目模式必须提供存在的 RightVideoPath。');
    end
    if isempty(config.calibrationFile) || ~isfile(config.calibrationFile)
        error('双目模式必须提供 CalibrationFile。');
    end
end
if ~ismember(config.filter, {'geometry', 'generic'})
    error('Filter 只能是 geometry 或 generic。');
end
config.analysisDirection = lower(char(config.analysisDirection));
if ~ismember(config.analysisDirection, {'x', 'y', 'both'})
    error('AnalysisDirection 只能是 x、y 或 both。单目中 x=水平/u，y=垂直/v。');
end
end

function [frames, info] = read_video_sequence(videoPath, config)
% 只读取请求的帧数，保留实际帧数；不修改原始视频。
reader = VideoReader(videoPath);
if isempty(config.fpsOverride)
    fps = reader.FrameRate;
else
    fps = config.fpsOverride;
end
if config.startFrame > 1
    for k = 1:config.startFrame - 1
        if ~hasFrame(reader)
            error('StartFrame 超出视频长度：%s', videoPath);
        end
        readFrame(reader);
    end
end
if ~hasFrame(reader)
    error('视频没有可读取的首帧：%s', videoPath);
end
first = to_gray_single(readFrame(reader));
[H, W] = size(first);
if isempty(config.roi)
    [roi, cancelled] = select_video_roi(first, videoPath);
    if cancelled
        error('ROI 选择已取消，程序退出；原始视频未被修改。');
    end
else
    roi = resolve_roi(config.roi, W, H);
end
if isinf(config.maxFrames)
    nTarget = max(2, floor(reader.Duration * fps));
else
    nTarget = config.maxFrames;
end
preflight_memory(config, roi, nTarget);
frames = zeros(roi(4), roi(3), nTarget, 'single');
frames(:, :, 1) = crop_frame(first, roi);
n = 1;
while n < nTarget && hasFrame(reader)
    frame = to_gray_single(readFrame(reader));
    if ~isequal(size(frame), [H, W])
        error('视频 %s 在第 %d 帧发生尺寸变化。', videoPath, n + 1);
    end
    n = n + 1;
    frames(:, :, n) = crop_frame(frame, roi);
end
if n < 2
    error('视频有效帧数少于 2：%s', videoPath);
end
frames = frames(:, :, 1:n);
info = struct();
info.path = videoPath;
info.frameRate = fps;
info.sourceFrameRate = reader.FrameRate;
info.height = H;
info.width = W;
info.frames = n;
info.duration = (n - 1) / fps;
info.roi = roi;
info.startFrame = config.startFrame;
end

function roi = resolve_roi(requested, W, H)
if isempty(requested)
    roi = [1, 1, W, H];
else
    roi = round(requested(:)');
    if roi(1) < 1 || roi(2) < 1 || roi(3) < 32 || roi(4) < 32 || ...
            roi(1) + roi(3) - 1 > W || roi(2) + roi(4) - 1 > H
        error('Roi=[x y width height] 超出图像边界 [%d %d]。', W, H);
    end
end
end

function preflight_memory(config, roi, nTarget)
% phase_flow_sequence 还会为每个方向保存多组单精度时序数组。
% 这里在分配大数组前给出可操作的错误，避免直接触发 MATLAB 内存不足。
cameraCount = 1;
if strcmp(config.mode, 'stereo')
    cameraCount = 2;
end
bytesPerPixelFrame = 4 * cameraCount + 48;  % 输入序列 + 一台相机的相位中间量
estimatedGB = double(roi(3)) * double(roi(4)) * double(nTarget) * ...
    bytesPerPixelFrame / 1024^3;
if estimatedGB > config.memoryBudgetGB
    safeFrames = floor(config.memoryBudgetGB * 1024^3 / ...
        (double(roi(3)) * double(roi(4)) * bytesPerPixelFrame));
    error(['预计运行至少需要约 %.2f GB，超过 memoryBudgetGB=%.2f GB。', ...
        '请缩小 ROI、将 MaxFrames 设为不超过 %d，或提高内存预算；', ...
        '程序已在分配前安全停止。'], ...
        estimatedGB, config.memoryBudgetGB, max(2, safeFrames));
end
end

function [roi, cancelled] = select_video_roi(firstFrame, videoPath)
% 首帧交互选 ROI：双击矩形或按 Enter 确认，按 Esc/关闭窗口取消。
% 不设置“确定”按钮，避免按钮状态与 ROI 图形状态不同步。
roi = [];
cancelled = false;
fig = figure('Name', ['Select ROI - ' videoPath], 'Color', 'w', ...
    'NumberTitle', 'off', 'ToolBar', 'none', 'MenuBar', 'none');
ax = axes(fig);
imagesc(ax, firstFrame); axis(ax, 'image'); colormap(ax, gray(256));
title(ax, '拖动红色矩形；双击或按 Enter 确认；按 Esc 取消并退出程序');
xlabel(ax, 'x (pixel)'); ylabel(ax, 'y (pixel)');
rect = drawrectangle(ax, 'Color', [1 0 0], 'InteractionsAllowed', 'all');
confirmed = false;
listener = addlistener(rect, 'ROIClicked', @roi_clicked); %#ok<NASGU>
fig.KeyPressFcn = @key_pressed;
fig.CloseRequestFcn = @window_closed;
uiwait(fig);
if isgraphics(fig) && isvalid(rect) && confirmed
    roi = round(rect.Position);
else
    cancelled = true;
end
if isgraphics(fig)
    delete(fig);
end
if ~cancelled
    [H, W] = size(firstFrame);
    roi = resolve_roi(roi, W, H);
end

    function roi_clicked(~, evt)
        try
            selectionType = '';
            if isprop(evt, 'SelectionType')
                selectionType = evt.SelectionType;
            elseif isprop(evt, 'CurrentSelectionType')
                selectionType = evt.CurrentSelectionType;
            end
            if strcmpi(selectionType, 'double')
                confirmed = true;
                uiresume(fig);
            end
        catch
            % 某些 MATLAB 版本事件对象字段不同；Enter 仍可确认。
        end
    end

    function key_pressed(~, evt)
        if any(strcmpi(evt.Key, {'return', 'enter'}))
            confirmed = true;
            uiresume(fig);
        elseif strcmpi(evt.Key, 'escape')
            cancelled = true;
            uiresume(fig);
        end
    end

    function window_closed(~, ~)
        cancelled = true;
        uiresume(fig);
    end
end

function frame = crop_frame(frame, roi)
frame = frame(roi(2):roi(2) + roi(4) - 1, roi(1):roi(1) + roi(3) - 1);
end

function point = auto_reference_point(frame, roi)
% 留空 InitialPoint 时，选择 ROI 内部梯度较强且远离边缘的纹理点，仅作轨迹显示参考。
frame = double(frame);
[gradX, gradY] = gradient(frame);
score = hypot(gradX, gradY);
margin = max(4, round(min(size(frame)) / 20));
score(1:margin, :) = -Inf;
score(end-margin+1:end, :) = -Inf;
score(:, 1:margin) = -Inf;
score(:, end-margin+1:end) = -Inf;
[~, index] = max(score(:));
[row, col] = ind2sub(size(score), index);
point = [roi(1) + col - 1; roi(2) + row - 1];
end

function frame = to_gray_single(frame)
if ndims(frame) == 3
    if size(frame, 3) >= 3
        if isa(frame, 'uint8') || isa(frame, 'uint16') || isa(frame, 'int16')
            frame = rgb2gray(frame(:, :, 1:3));
        else
            frame = 0.2989 * frame(:, :, 1) + 0.5870 * frame(:, :, 2) + 0.1140 * frame(:, :, 3);
        end
    else
        frame = frame(:, :, 1);
    end
end
if isa(frame, 'uint8')
    frame = single(frame) / 255;
elseif isa(frame, 'uint16')
    frame = single(frame) / 65535;
elseif isa(frame, 'int16')
    frame = single(frame - double(intmin('int16'))) / double(intmax('int16') - intmin('int16'));
else
    frame = single(frame);
    maxValue = max(frame(:));
    if isfinite(maxValue) && maxValue > 1.5
        if maxValue <= 255 * 1.01
            frame = frame / 255;
        else
            frame = frame / maxValue;
        end
    end
end
frame = min(max(frame, 0), 1);
end

function cfg = make_runtime_config(config, video, frameSize)
cfg = pnl_config('demo');
cfg.fps = video.frameRate;
cfg.dt = 1 / video.frameRate;
cfg.nFrames = frameSize(3);
cfg.imageSize = [video.height, video.width];
cfg.roiSize = [frameSize(1), frameSize(2)];
cfg.roi = video.roi;
cfg.keepFlowFields = config.keepFlowFields;
cfg.RLG = config.localRotation;
cfg.motion.zStart = max(cfg.dt, (cfg.nFrames - 1) / (2 * cfg.fps));
end

function methods = run_mono_methods(frames, cfg, config)
methods = struct();
methods.(config.filter) = process_mono_method(frames, cfg, cfg.filter.(config.filter), config);
if config.runGeneric && ~strcmpi(config.filter, 'generic')
    methods.generic = process_mono_method(frames, cfg, cfg.filter.generic, config);
end
end

function result = process_mono_method(frames, cfg, filterCfg, config)
est = phase_flow_sequence(frames, cfg, filterCfg, false);
if isempty(config.initialPoint)
    point0 = auto_reference_point(frames(:, :, 1), cfg.roi);
else
    point0 = config.initialPoint(:);
end
result = struct();
result.filter = filterCfg;
result.camera = est;
result.initialPoint = point0;
result.time = (0:size(frames, 3) - 1) / cfg.fps;
result.pointUV = point0 + est.cumulativeUV;
result.displacementUV = est.cumulativeUV;
result.pnlScalar = est.pnlScalar;
end

function initialPoints = resolve_stereo_initial_points(config, leftVideo, rightVideo, leftFrames, rightFrames)
if ~isempty(config.initialPoints)
    initialPoints = double(config.initialPoints);
    return;
end
if isempty(config.initialPoint)
    leftRoi = leftVideo.roi;
    rightRoi = rightVideo.roi;
    leftCenter = auto_reference_point(leftFrames(:, :, 1), leftRoi);
    rightCenter = auto_reference_point(rightFrames(:, :, 1), rightRoi);
else
    leftCenter = config.initialPoint(:);
    rightCenter = leftCenter;
end
initialPoints = [leftCenter, rightCenter];
warning('双目未提供 InitialPoints，左右相机均自动选择 ROI 内纹理参考点。');
if size(leftFrames, 1) ~= size(rightFrames, 1) || size(leftFrames, 2) ~= size(rightFrames, 2)
    error('当前入口要求左右 ROI 尺寸一致。');
end
end

function methods = run_stereo_methods(leftFrames, rightFrames, cfg, config, initialPoints)
[P1, P2, calibrationInfo] = load_projection_matrices(config.calibrationFile);
cfg.P{1} = P1;
cfg.P{2} = P2;
methods = struct();
methods.(config.filter) = process_stereo_method(leftFrames, rightFrames, cfg, ...
    cfg.filter.(config.filter), initialPoints, config, calibrationInfo);
if config.runGeneric && ~strcmpi(config.filter, 'generic')
    methods.generic = process_stereo_method(leftFrames, rightFrames, cfg, ...
        cfg.filter.generic, initialPoints, config, calibrationInfo);
end
end

function result = process_stereo_method(leftFrames, rightFrames, cfg, filterCfg, initialPoints, config, calibrationInfo)
left = phase_flow_sequence(leftFrames, cfg, filterCfg, false);
right = phase_flow_sequence(rightFrames, cfg, filterCfg, false);
uv = zeros(2, size(leftFrames, 3), 2);
uv(:, :, 1) = initialPoints(:, 1) + left.cumulativeUV;
uv(:, :, 2) = initialPoints(:, 2) + right.cumulativeUV;
xyzGlobal = config.worldScale * triangulate_stereo_sequence(cfg, uv);
if isempty(config.localOrigin)
    cfg.marker.center = xyzGlobal(:, 1);
else
    cfg.marker.center = config.localOrigin(:);
end
xyzLocal = local_coordinates(xyzGlobal, cfg);
result = struct();
result.filter = filterCfg;
result.camera(1) = left;
result.camera(2) = right;
result.uv = uv;
result.xyzGlobal = xyzGlobal;
result.xyz = xyzLocal;
result.displacement = xyzLocal - xyzLocal(:, 1);
result.calibration = calibrationInfo;
end

function out = build_mono_output(config, video, primary, methods, cfg)
out = struct();
out.type = 'real_video_entry';
out.mode = 'mono';
out.video = video;
out.options = config;
out.config = cfg;
out.methods = methods;
out.primaryMethod = config.filter;
out.initialPoint = primary.initialPoint;
out.pointUV = primary.pointUV;
out.displacementUV = primary.displacementUV;
out.pnlScalar = primary.pnlScalar;
out.pnlMap = primary.camera.pnlMap;
out.time = primary.time;
out.analysisDirection = config.analysisDirection;
[out.directionIndices, out.directionLabels] = direction_indices(config.analysisDirection);
out.selectedDisplacementUV = out.displacementUV(out.directionIndices, :);
out.spectrum = compute_spectrum(out.time, out.selectedDisplacementUV, ...
    out.directionLabels, video.frameRate);
end

function out = build_stereo_output(config, leftVideo, rightVideo, primary, methods, cfg, initialPoints)
out = struct();
out.type = 'real_video_entry';
out.mode = 'stereo';
out.video = struct('left', leftVideo, 'right', rightVideo, ...
    'frameRate', leftVideo.frameRate, 'frames', leftVideo.frames, ...
    'duration', leftVideo.duration);
out.options = config;
out.config = cfg;
out.methods = methods;
out.primaryMethod = ternary_method_name(methods);
out.initialPoints = initialPoints;
out.calibration = primary.calibration;
out.uv = primary.uv;
out.xyzGlobal = primary.xyzGlobal;
out.xyz = primary.xyz;
out.displacement = primary.displacement;
out.analysisDirection = config.analysisDirection;
out.directionIndices = 1:3;
out.directionLabels = {'X', 'Y', 'Z'};
out.spectrum = compute_spectrum((0:size(out.displacement, 2) - 1) / cfg.fps, ...
    out.displacement, out.directionLabels, cfg.fps);
end

function name = ternary_method_name(methods)
if isfield(methods, 'geometry')
    name = 'geometry';
else
    names = fieldnames(methods);
    name = names{1};
end
end

function outputDirectory = prepare_output_directory(requested, projectRoot)
if isempty(requested)
    outputDirectory = fullfile(projectRoot, 'outputs', 'real', ...
        ['run_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))]);
else
    outputDirectory = requested;
end
if ~exist(outputDirectory, 'dir')
    mkdir(outputDirectory);
end
end

function [P1, P2, meta] = load_projection_matrices(path)
S = load(path);
meta = struct('file', path, 'source', '');
if isfield(S, 'P') && iscell(S.P) && numel(S.P) >= 2
    P1 = double(S.P{1}); P2 = double(S.P{2});
    meta.source = 'P{1}/P{2}';
elseif isfield(S, 'P1') && isfield(S, 'P2')
    P1 = double(S.P1); P2 = double(S.P2);
    meta.source = 'P1/P2';
elseif isfield(S, 'stereoParams')
    stereoParams = S.stereoParams;
    K1 = double(stereoParams.CameraParameters1.IntrinsicMatrix');
    K2 = double(stereoParams.CameraParameters2.IntrinsicMatrix');
    R = double(stereoParams.RotationOfCamera2);
    T = double(stereoParams.TranslationOfCamera2(:));
    P1 = K1 * [eye(3), zeros(3, 1)];
    P2 = K2 * [R, T];
    meta.source = 'stereoParameters';
else
    error('CalibrationFile 中未找到 P{1}/P{2}、P1/P2 或 stereoParams。');
end
if ~isequal(size(P1), [3, 4]) || ~isequal(size(P2), [3, 4]) || ...
        any(~isfinite([P1(:); P2(:)]))
    error('标定投影矩阵必须是有限的 3x4 数值矩阵。');
end
end

function plot_real_outputs(out, leftFrames, rightFrames)
if strcmp(out.mode, 'mono')
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 700]);
    axInput = subplot(1, 2, 1); imagesc(axInput, leftFrames(:, :, 1)); axis(axInput, 'image');
    axis(axInput, 'off'); colormap(axInput, gray(256)); title(axInput, 'Input frame');
    axPnl = subplot(1, 2, 2); imagesc(axPnl, log10(1 + min(out.pnlMap, 1e3))); axis(axPnl, 'image');
    colormap(axPnl, parula(256)); colorbar(axPnl);
    title(axPnl, [out.primaryMethod ' PNL']); xlabel(axPnl, 'u'); ylabel(axPnl, 'v');
    save_figure(fig, fullfile(out.outputDirectory, 'real_mono_result.png')); close(fig);
    plot_waveform_figure(out.outputDirectory, out.time, out.selectedDisplacementUV, ...
        out.directionLabels, 'Mono ROI displacement waveform', 'Pixel displacement');
    plot_spectrum_figure(out.outputDirectory, out.spectrum, 'Mono ROI displacement spectrum', ...
        'Amplitude (pixel)');
else
    primary = out.methods.(out.primaryMethod);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 420]);
    axLeft = subplot(1, 2, 1); imagesc(axLeft, leftFrames(:, :, 1)); axis(axLeft, 'image');
    axis(axLeft, 'off'); colormap(axLeft, gray(256)); title(axLeft, 'Left input frame');
    axRight = subplot(1, 2, 2); imagesc(axRight, rightFrames(:, :, 1)); axis(axRight, 'image');
    axis(axRight, 'off'); colormap(axRight, gray(256)); title(axRight, 'Right input frame');
    save_figure(fig, fullfile(out.outputDirectory, 'real_video_preview.png')); close(fig);
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 420]);
    axLeftPnl = subplot(1, 2, 1); imagesc(axLeftPnl, log10(1 + min(primary.camera(1).pnlMap, 1e3)));
    axis(axLeftPnl, 'image'); colormap(axLeftPnl, parula(256)); colorbar(axLeftPnl);
    title(axLeftPnl, [out.primaryMethod ' PNL, left camera']); xlabel(axLeftPnl, 'u'); ylabel(axLeftPnl, 'v');
    axRightPnl = subplot(1, 2, 2); imagesc(axRightPnl, log10(1 + min(primary.camera(2).pnlMap, 1e3)));
    axis(axRightPnl, 'image'); colormap(axRightPnl, parula(256)); colorbar(axRightPnl);
    title(axRightPnl, [out.primaryMethod ' PNL, right camera']); xlabel(axRightPnl, 'u'); ylabel(axRightPnl, 'v');
    save_figure(fig, fullfile(out.outputDirectory, 'real_pnl_maps.png')); close(fig);
    t = (0:size(primary.displacement, 2) - 1) / out.config.fps;
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 700]);
    labels = {'X', 'Y', 'Z'};
    for k = 1:3
        ax = subplot(3, 1, k); plot(ax, t, primary.displacement(k, :), ...
            'Color', [0.05 0.35 0.80], 'LineWidth', 1.0); grid(ax, 'on');
        ylabel(ax, [labels{k} ' (calibration unit)']);
    end
    xlabel(ax, 'Time (s)');
    save_figure(fig, fullfile(out.outputDirectory, 'real_3d_displacement.png')); close(fig);
    plot_waveform_figure(out.outputDirectory, t, primary.displacement, labels, ...
        'Stereo reconstructed displacement waveform', 'Displacement (calibration unit)');
    plot_spectrum_figure(out.outputDirectory, out.spectrum, ...
        'Stereo reconstructed displacement spectrum', 'Amplitude (calibration unit)');
end
end

function plot_waveform_figure(outputDirectory, time, signals, labels, titleText, yLabel)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 600]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
colors = [0.0000 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.4660 0.6740 0.1880];
for k = 1:size(signals, 1)
    plot(ax, time, signals(k, :), 'LineWidth', 1.2, 'Color', colors(1 + mod(k - 1, size(colors, 1)), :));
end
xlabel(ax, 'Time (s)'); ylabel(ax, yLabel); title(ax, titleText);
legend(ax, labels, 'Location', 'best');
save_figure(fig, fullfile(outputDirectory, 'real_waveform.png')); close(fig);
end

function plot_spectrum_figure(outputDirectory, spectrum, titleText, yLabel)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1100 600]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
colors = [0.0000 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.4660 0.6740 0.1880];
for k = 1:size(spectrum.amplitude, 2)
    plot(ax, spectrum.frequencyHz, spectrum.amplitude(:, k), 'LineWidth', 1.2, ...
        'Color', colors(1 + mod(k - 1, size(colors, 1)), :));
end
xlabel(ax, 'Frequency (Hz)'); ylabel(ax, yLabel); title(ax, titleText);
legend(ax, spectrum.labels, 'Location', 'best');
save_figure(fig, fullfile(outputDirectory, 'real_spectrum.png')); close(fig);
end

function write_real_metadata(out)
fid = fopen(fullfile(out.outputDirectory, 'real_video_metadata.txt'), 'w');
fprintf(fid, 'type=real_video_entry\nmode=%s\n', out.mode);
if strcmp(out.mode, 'mono')
    fprintf(fid, 'video=%s\n', out.video.path);
    fprintf(fid, 'frames=%d\nfps=%.12g\nduration_s=%.12g\n', ...
        out.video.frames, out.video.frameRate, out.video.duration);
    fprintf(fid, 'roi=[%d %d %d %d]\n', out.video.roi(1), out.video.roi(2), ...
        out.video.roi(3), out.video.roi(4));
else
    fprintf(fid, 'left=%s\nright=%s\n', out.video.left.path, out.video.right.path);
    fprintf(fid, 'frames=%d\nfps=%.12g\nduration_s=%.12g\n', ...
        out.video.frames, out.video.frameRate, out.video.duration);
    fprintf(fid, 'calibration=%s\nsource=%s\n', out.options.calibrationFile, ...
        out.methods.(out.primaryMethod).calibration.source);
end
fprintf(fid, 'primary_method=%s\n', out.primaryMethod);
fprintf(fid, 'analysis_direction=%s\n', out.analysisDirection);
fprintf(fid, 'waveform_file=real_waveform.png;real_waveform.fig\n');
fprintf(fid, 'spectrum_file=real_spectrum.png;real_spectrum.fig\n');
if strcmp(out.mode, 'mono')
    fprintf(fid, 'roi_video=%s\nroi_video_codec=%s\n', out.roiVideo.path, out.roiVideo.codec);
else
    fprintf(fid, 'roi_video_left=%s\nroi_video_right=%s\nroi_video_codec=Uncompressed AVI\n', ...
        out.roiVideo.left.path, out.roiVideo.right.path);
end
fclose(fid);
end

function save_figure(fig, path)
try
    exportgraphics(fig, path, 'Resolution', 300);
catch
    saveas(fig, path);
end
[folder, name] = fileparts(path);
figPath = fullfile(folder, [name '.fig']);
oldVisible = fig.Visible;
fig.Visible = 'on';
savefig(fig, figPath);
fig.Visible = oldVisible;
end

function [indices, labels] = direction_indices(direction)
switch lower(char(direction))
    case 'x'
        indices = 1;
        labels = {'x (horizontal/u)'};
    case 'y'
        indices = 2;
        labels = {'y (vertical/v)'};
    otherwise
        indices = [1 2];
        labels = {'x (horizontal/u)', 'y (vertical/v)'};
end
end

function spectrum = compute_spectrum(time, signals, labels, fps)
% 单边幅值谱：去均值并使用 Hann 窗，避免位移直流项压低动态成分。
signals = double(signals);
n = size(signals, 2);
if n < 2
    error('频谱分析至少需要 2 帧。');
end
window = 0.5 - 0.5 * cos(2 * pi * (0:n - 1) / (n - 1));
frequency = (0:floor(n / 2))' * fps / n;
amplitude = zeros(numel(frequency), size(signals, 1));
for k = 1:size(signals, 1)
    signal = signals(k, :);
    if any(~isfinite(signal))
        signal(~isfinite(signal)) = 0;
    end
    signal = signal - mean(signal);
    transformed = fft(signal .* window);
    oneSided = abs(transformed(1:numel(frequency))) / sum(window);
    if numel(oneSided) > 2
        oneSided(2:end-1) = 2 * oneSided(2:end-1);
    end
    amplitude(:, k) = oneSided;
end
spectrum = struct('time', time, 'frequencyHz', frequency, 'amplitude', amplitude, ...
    'labels', {labels}, 'method', 'mean removal + Hann window + single-sided amplitude spectrum');
end

function info = write_roi_video(frames, fps, path)
% 输出无压缩 AVI，避免依赖 Motion-JPEG 解码器。
writer = VideoWriter(path, 'Uncompressed AVI');
writer.FrameRate = fps;
try
    open(writer);
    for k = 1:size(frames, 3)
        frame = uint8(max(0, min(1, frames(:, :, k))) * 255);
        writeVideo(writer, frame);
    end
    close(writer);
catch ME
    try
        close(writer);
    catch
    end
    error('ROI 无压缩 AVI 写入失败：%s', ME.message);
end
info = struct('path', path, 'codec', 'Uncompressed AVI', ...
    'frames', size(frames, 3), 'frameRate', fps);
end

function tf = is_text_scalar(x)
tf = ischar(x) || (isstring(x) && isscalar(x));
end
