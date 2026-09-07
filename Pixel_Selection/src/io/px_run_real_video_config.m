function result = px_run_real_video_config(config, projectRoot)
% 按真实视频入口配置运行当前论文方法。
% 入口脚本只编排流程；论文核心算法仍由src/core中的函数执行。
if nargin < 2 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end
if ~isfield(config, 'videoPath') || isempty(strtrim(config.videoPath))
    error('config.videoPath为空，请在scripts/run_real_video.m顶部填写视频路径。');
end
if ~isfile(config.videoPath)
    error('找不到真实视频：%s', config.videoPath);
end

% 先读取首帧并完成ROI，ROI取消时不清理已有结果。
[roi, firstFrame, firstCrop, cancelled] = px_select_video_roi(config.videoPath, config.roi, ...
    ['Pixel Selection ROI - ', config.outputName]);
if cancelled
    result = struct('status', 'cancelled', 'videoPath', config.videoPath);
    disp('ROI选择已取消，既有输出目录未被修改。');
    return;
end

outputRoot = config.outputDirectory;
outputsRoot = fullfile(projectRoot, 'outputs');
if isfield(config.output, 'clearPreviousResults') && config.output.clearPreviousResults
    if ~px_is_child_path(outputRoot, outputsRoot)
        error('为避免误删，清理目录必须位于当前工程outputs目录内：%s', outputsRoot);
    end
    if exist(outputRoot, 'dir')
        rmdir(outputRoot, 's');
    end
end
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

cfg = px_default_config();
cfg.io.roi = roi;
cfg.io.maxFrames = config.maxFrames;
cfg.io.saveVideo = false;
cfg.io.saveIntermediate = true;
cfg.io.writeRoiAvi = config.output.writeRoiAvi;
cfg.io.outputName = config.outputName;
cfg.direction.analysis = lower(strtrim(config.direction));
if ~isempty(config.fpsOverride)
    cfg.io.fpsOverride = config.fpsOverride;
end

[video, metadata] = px_read_real_video(config.videoPath, cfg);
videoFps = metadata.frameRate;
processingFps = videoFps;
if ~isempty(config.fpsOverride)
    processingFps = config.fpsOverride;
end
if processingFps <= 0
    error('处理帧率必须为正数。');
end

% 论文方法使用固定ROI；这里保存首帧裁剪图作为输入证据。
dirs = px_prepare_folders(outputRoot);
imwrite(px_to_uint8(firstCrop), fullfile(dirs.process, [config.outputName, '_roi_first_frame.png']));
result = px_run_pipeline(video, processingFps, outputRoot, [], cfg, 'real_video');

% 用户明确要求使用无压缩AVI，避免Motion-JPEG解码依赖。
if config.output.writeRoiAvi
    aviPath = fullfile(dirs.videos, [config.outputName, '_roi_uncompressed.avi']);
    px_write_uncompressed_avi(video, processingFps, aviPath);
    result.roiVideo = aviPath;
end

metadata.videoFps = videoFps;
metadata.processingFps = processingFps;
metadata.requestedMaxFrames = config.maxFrames;
metadata.firstFrameCropSize = size(firstCrop);
metadata.outputDirectory = outputRoot;
metadata.direction = cfg.direction.analysis;
save(fullfile(outputRoot, 'real_video_metadata.mat'), 'metadata', 'cfg', 'config', ...
    'roi', 'firstFrame', 'firstCrop', '-v7.3');
px_write_json(config, fullfile(outputRoot, 'real_video_config.json'));
disp('真实视频处理已完成；无外部真值时PF/FE/PER/RMSE/PCC保持NaN。');
disp(result);
end

function tf = px_is_child_path(childPath, parentPath)
childPath = lower(strrep(char(childPath), '/', '\'));
parentPath = lower(strrep(char(parentPath), '/', '\'));
if ~endsWith(parentPath, '\')
    parentPath = [parentPath, '\'];
end
tf = startsWith(childPath, parentPath) && ~strcmp(childPath, parentPath(1:end-1));
end

function image = px_to_uint8(frame)
frame = double(frame);
if max(frame(:)) <= 1
    frame = frame * 255;
end
image = uint8(round(min(max(frame, 0), 255)));
end
