function ok = write_video_stream(getFrame, frameCount, frameRate, outputPath)
%WRITE_VIDEO_STREAM 将模拟帧写为 AVI，保留可回放的视频证据。
ok=false;
try
    writer=VideoWriter(outputPath,'Motion JPEG AVI'); writer.FrameRate=frameRate; writer.Quality=90; open(writer);
    for i=1:frameCount
        I=getFrame(i); if size(I,3)==1, I=repmat(im2uint8(I),1,1,3); else, I=im2uint8(I); end
        writeVideo(writer,I);
    end
    close(writer); ok=true;
catch ME
    if exist('writer','var'), try, close(writer); catch, end, end
    warning('TDDM:VideoWriteFailed','Video was not written: %s',ME.message);
end
end
