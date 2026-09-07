function write_video_preview(video, filePath, frameRate)
%WRITE_VIDEO_PREVIEW 保存论文复现所需的模拟视频证据。
try
    writer=VideoWriter(filePath,'Motion JPEG AVI'); writer.FrameRate=frameRate; open(writer);
    for k=1:size(video,3), writeVideo(writer,video(:,:,k)); end
    close(writer);
catch err
    warning('无法写入 MPEG-4 视频：%s。改为不阻塞主实验。',err.message);
end
end
