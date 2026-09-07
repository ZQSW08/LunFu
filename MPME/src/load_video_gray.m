function [frames, fps] = load_video_gray(videoPath, maxFrames, roi)
%LOAD_VIDEO_GRAY 读取灰度视频并裁剪 ROI；帧缓存使用 single 降低真实视频内存占用。

if nargin < 2 || isempty(maxFrames), maxFrames = Inf; end
if nargin < 3, roi = []; end
reader = VideoReader(videoPath);
fps = reader.FrameRate;
estimatedCount = min(maxFrames, max(1, floor(reader.Duration * fps)));
frames = [];
frameIndex = 0;
while hasFrame(reader) && frameIndex < estimatedCount
    rgb = readFrame(reader);
    if size(rgb, 3) == 3, gray = rgb2gray(rgb); else, gray = rgb; end
    if ~isempty(roi), gray = imcrop(gray, roi); end
    frameIndex = frameIndex + 1;
    if frameIndex == 1
        % 后续相位运算会在需要时转为 double；这里用 single 可将缓存内存减半。
        frames = zeros(size(gray,1), size(gray,2), estimatedCount, 'single');
    end
    frames(:, :, frameIndex) = double(gray);
end
frames = frames(:, :, 1:frameIndex);
end
