function [ok,message]=write_tracking_video(source,trace,rects,fps,path)
%WRITE_TRACKING_VIDEO 保存原图上的跟随 ROI 和最终测点。
ok=false; message='';
try
    writer=VideoWriter(path,'Motion JPEG AVI'); writer.FrameRate=fps; open(writer);
    cleanup=onCleanup(@() close(writer)); %#ok<NASGU>
    for i=1:source.count
        I=source.getFrame(i); if ~isa(I,'uint8'), I=im2uint8(I); end
        if size(I,3)==1, I=repmat(I,[1 1 3]); end
        I=insertShape(I,'Rectangle',rects(i,:),'Color','green','LineWidth',2);
        p=trace(i).pFinal; if all(isfinite(p)), I=insertMarker(I,p,'+','Color','red','Size',8); end
        writeVideo(writer,I);
    end
    close(writer);
    % 写出后立即回读一帧，避免生成“有文件但播放器无法识别”的伪成功结果。
    checkReader=VideoReader(path);
    if ~hasFrame(checkReader), error('跟踪视频写出后无法回读首帧。'); end
    checkFrame=readFrame(checkReader); %#ok<NASGU>
    ok=true;
catch ME
    message=ME.message;
end
end
