function [frames, videoInfo] = apcv_read_real_video(videoPath, roi, maxFrames, fpsOverride, timeWindow)
%APCV_READ_REAL_VIDEO 读取真实视频、裁剪固定 ROI 并保存帧率/帧索引元数据。
% 未指定 captureFps 时，fpsOverride 只接受整数抽帧比；指定 captureFps 后，
% 每个可读取帧按真实采集帧率建立时间轴，fpsOverride 不再改变处理帧率。

if nargin < 3 || isempty(maxFrames)
    maxFrames = Inf;
end
if nargin < 4
    fpsOverride = [];
end
if nargin < 5 || isempty(timeWindow)
    timeWindow = struct();
end
reader = VideoReader(videoPath);
videoFps = reader.FrameRate;
captureFps = getWindowValue(timeWindow,'captureFps',videoFps);
captureFpsProvided = isfield(timeWindow,'captureFps') && ~isempty(timeWindow.captureFps);
if ~isscalar(captureFps) || ~isfinite(captureFps) || captureFps <= 0
    error('timeWindow.captureFps 必须是正的有限采集帧率。');
end
if captureFpsProvided
    stride = 1;
    processingFps = captureFps;
elseif isempty(fpsOverride)
    stride = 1;
    processingFps = videoFps;
else
    if fpsOverride <= 0 || fpsOverride > videoFps
        error('fpsOverride 必须在 (0, videoFps] 内。视频帧率为 %.6g Hz。', videoFps);
    end
    stride = max(1, round(videoFps / fpsOverride));
    processingFps = videoFps / stride;
    if abs(processingFps - fpsOverride) > max(0.01, 0.01*fpsOverride)
        error(['当前入口只接受整数抽帧比：原始 %.6g Hz，目标 %.6g Hz 不匹配。' ...
            ' 请将 fpsOverride 设为 [] 或选择原始帧率的整数分频。'], videoFps, fpsOverride);
    end
end

[roi, ok, message] = apcv_validate_roi(roi, [reader.Height, reader.Width]);
if ~ok
    error('ROI 无效：%s', message);
end

maxReadable = floor(reader.Duration * videoFps) + 2;
startSeconds = getWindowValue(timeWindow,'startSeconds',0);
durationSeconds = getWindowValue(timeWindow,'durationSeconds',Inf);
if ~isscalar(startSeconds) || ~isfinite(startSeconds) || startSeconds < 0
    error('timeWindow.startSeconds 必须是非负有限标量。');
end
if ~(isscalar(durationSeconds) && ((isfinite(durationSeconds) && durationSeconds > 0) || isinf(durationSeconds)))
    error('timeWindow.durationSeconds 必须为正数或 Inf。');
end
if ~isscalar(captureFps) || ~isfinite(captureFps) || captureFps <= 0
    error('timeWindow.captureFps 必须是正的有限采集帧率。');
end
startCaptureFrame = floor(startSeconds*captureFps)+1;
if captureFpsProvided
    startSourceIndex = startCaptureFrame;
else
    startSourceIndex = round((startCaptureFrame-1)*videoFps/captureFps)+1;
end
if isfinite(durationSeconds)
    endCaptureFrame = floor((startSeconds+durationSeconds)*captureFps)+1;
    if captureFpsProvided
        endSourceIndex = min(maxReadable,endCaptureFrame);
    else
        endSourceIndex = min(maxReadable, round((endCaptureFrame-1)*videoFps/captureFps)+1);
    end
else
    endSourceIndex = maxReadable;
end
if startSourceIndex > endSourceIndex
    error('timeWindow 起始时间超出视频时长。');
end
if isfinite(maxFrames)
    expected = min(endSourceIndex-startSourceIndex+1, max(1, floor(maxFrames)));
else
    expected = endSourceIndex-startSourceIndex+1;
end
h = roi(4); w = roi(3);
frames = zeros(h, w, max(1, expected), 'single');
frameIndices = zeros(max(1, expected), 1);
readIndex = 0; stored = 0;
while hasFrame(reader)
    raw = readFrame(reader);
    readIndex = readIndex + 1;
    if readIndex < startSourceIndex
        continue;
    end
    if readIndex > endSourceIndex
        break;
    end
    if mod(readIndex-startSourceIndex, stride) ~= 0
        continue;
    end
    stored = stored + 1;
    if stored > size(frames,3)
        frames(:, :, end+max(100, round(size(frames,3)/2))) = single(0);
        frameIndices(end+max(100, round(numel(frameIndices)/2)),1) = 0;
    end
    if size(raw,3) == 3
        raw = rgb2gray(raw);
    end
    crop = raw(roi(2):roi(2)+roi(4)-1, roi(1):roi(1)+roi(3)-1);
    frames(:, :, stored) = im2single(crop);
    frameIndices(stored) = readIndex;
    if stored >= maxFrames
        break;
    end
end
if stored < 3
    error('可处理帧数不足：实际只有 %d 帧，至少需要 3 帧。', stored);
end
frames = frames(:, :, 1:stored);
frameIndices = frameIndices(1:stored);

videoInfo.path = videoPath;
videoInfo.videoFps = videoFps;
videoInfo.processingFps = processingFps;
videoInfo.frameCount = stored;
videoInfo.requestedMaxFrames = maxFrames;
videoInfo.frameIndices = frameIndices;
videoInfo.time = (frameIndices - 1) / videoFps;
videoInfo.originalWidth = reader.Width;
videoInfo.originalHeight = reader.Height;
videoInfo.roi = roi;
videoInfo.durationSeconds = videoInfo.time(end) - videoInfo.time(1);
videoInfo.windowStartSeconds = startSeconds;
videoInfo.windowDurationSeconds = durationSeconds;
videoInfo.captureFps = captureFps;
if captureFpsProvided
    videoInfo.captureFrameIndices = frameIndices;
else
    videoInfo.captureFrameIndices = round((frameIndices-1)*captureFps/videoFps)+1;
end
videoInfo.captureTime = (videoInfo.captureFrameIndices-1)/captureFps;
if captureFpsProvided, videoInfo.time = videoInfo.captureTime; end
end

function value = getWindowValue(timeWindow,name,defaultValue)
if isstruct(timeWindow) && isfield(timeWindow,name) && ~isempty(timeWindow.(name))
    value = double(timeWindow.(name));
else
    value = defaultValue;
end
end
