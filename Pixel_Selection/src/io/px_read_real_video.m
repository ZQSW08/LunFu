function [video, metadata] = px_read_real_video(videoPath, cfg)
% 读取真实视频，转为高度×宽度×帧数的单精度灰度数组。
% ROI格式为[x, y, width, height]，坐标遵循MATLAB图像坐标从1开始。
if ~isfile(videoPath)
    error('找不到输入视频：%s', videoPath);
end
reader = VideoReader(videoPath);
frameRate = reader.FrameRate;
frameLimit = cfg.io.maxFrames;
if isinf(frameLimit)
    frameLimit = floor(reader.Duration * frameRate) + 1;
else
    frameLimit = min(floor(frameLimit), floor(reader.Duration * frameRate) + 1);
end
if frameLimit < 2
    error('真实视频至少需要两帧。');
end

firstFrame = readFrame(reader);
firstGray = px_to_gray(firstFrame);
roi = cfg.io.roi;
if ~isempty(roi)
    roi = round(roi(:)');
    if numel(roi) ~= 4 || roi(1) < 1 || roi(2) < 1 || roi(3) < 2 || roi(4) < 2
        error('cfg.io.roi必须是有效的[x,y,width,height]。');
    end
    xLast = min(size(firstGray, 2), roi(1) + roi(3) - 1);
    yLast = min(size(firstGray, 1), roi(2) + roi(4) - 1);
    firstGray = firstGray(roi(2):yLast, roi(1):xLast);
else
    xLast = []; yLast = [];
end
video = zeros(size(firstGray, 1), size(firstGray, 2), frameLimit, 'single');
video(:, :, 1) = firstGray;
frameIndex = 2;
while hasFrame(reader) && frameIndex <= frameLimit
    frame = px_to_gray(readFrame(reader));
    if ~isempty(roi)
        frame = frame(roi(2):yLast, roi(1):xLast);
    end
    video(:, :, frameIndex) = frame;
    frameIndex = frameIndex + 1;
end
video = video(:, :, 1:frameIndex-1);
metadata.path = videoPath;
metadata.frameRate = frameRate;
metadata.frameCount = size(video, 3);
metadata.height = size(video, 1);
metadata.width = size(video, 2);
metadata.roi = roi;
metadata.durationSeconds = metadata.frameCount / frameRate;
end

function gray = px_to_gray(frame)
% 使用固定亮度权重转换RGB，避免依赖im2gray。
frame = single(frame);
if ndims(frame) == 3
    gray = 0.298936 * frame(:, :, 1) + 0.587043 * frame(:, :, 2) + 0.114021 * frame(:, :, 3);
else
    gray = frame;
end
if max(gray(:)) > 1
    gray = gray / 255;
end
gray = min(max(gray, 0), 1);
end
