function px_write_video(video, fs, filePath)
% 将归一化灰度数组写成便于人工复查的MP4视频。
try
    writer = VideoWriter(filePath, 'MPEG-4');
catch
    [folder, name] = fileparts(filePath);
    filePath = fullfile(folder, [name, '.avi']);
    writer = VideoWriter(filePath, 'Motion JPEG AVI');
end
writer.FrameRate = fs;
open(writer);
cleanup = onCleanup(@() close(writer));
for frameIndex = 1:size(video, 3)
    frame = uint8(min(max(video(:, :, frameIndex), 0), 1) * 255);
    writeVideo(writer, frame);
end
end
