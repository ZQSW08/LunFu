function px_write_uncompressed_avi(video, fs, filePath)
% 写出无压缩AVI，避免依赖Motion-JPEG解码器查看ROI视频。
% 输入video为高度×宽度×帧数，数值范围建议为[0,1]。
folder = fileparts(filePath);
if ~exist(folder, 'dir')
    mkdir(folder);
end
try
    writer = VideoWriter(filePath, 'Uncompressed AVI');
catch exception
    error('当前MATLAB无法创建无压缩AVI写入器：%s', exception.message);
end
writer.FrameRate = fs;
open(writer);
cleanup = onCleanup(@() close(writer));
for frameIndex = 1:size(video, 3)
    frame = uint8(round(min(max(double(video(:, :, frameIndex)), 0), 1) * 255));
    % 写入无压缩RGB帧，兼容Windows下常见的视频查看器。
    writeVideo(writer, repmat(frame, 1, 1, 3));
end
end
