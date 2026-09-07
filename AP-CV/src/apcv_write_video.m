function apcv_write_video(frames, outputPath, frameRate, maxFrames)
%APCV_WRITE_VIDEO 保存代表性合成图像序列，作为算法输入证据。

n = min(size(frames, 3), maxFrames);
writer = VideoWriter(outputPath, 'Motion JPEG AVI');
writer.FrameRate = frameRate;
writer.Quality = 90;
open(writer);
cleanupObj = onCleanup(@() close(writer)); %#ok<NASGU>
for k = 1:n
    writeVideo(writer, im2uint8(frames(:, :, k)));
end
end
