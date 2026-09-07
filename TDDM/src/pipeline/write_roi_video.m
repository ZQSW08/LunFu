function [ok,message]=write_roi_video(source,rects,fps,path)
%WRITE_ROI_VIDEO 保存固定或跟随 ROI 的裁剪视频。
ok=false; message='';
try
    writer=VideoWriter(path,'Motion JPEG AVI'); writer.FrameRate=fps; open(writer);
    cleanup=onCleanup(@() close(writer)); %#ok<NASGU>
    for i=1:source.count
        I=source.getFrame(i); [~,crop,cancelled]=crop_frame(I,rects(i,:));
        if cancelled, error('ROI 在第 %d 帧越界。',i); end
        if ~isa(crop,'uint8'), crop=im2uint8(crop); end
        writeVideo(writer,crop);
    end
    close(writer);
    % 对裁剪视频做一次最小回读验证，确保 AVI 头和帧格式有效。
    checkReader=VideoReader(path);
    if ~hasFrame(checkReader), error('ROI 裁剪视频写出后无法回读首帧。'); end
    checkFrame=readFrame(checkReader); %#ok<NASGU>
    ok=true;
catch ME
    message=ME.message;
end
end
function [roi,crop,cancelled]=crop_frame(I,roi)
cancelled=false; roi=double(roi(:)');
x=round(roi(1)); y=round(roi(2)); w=round(roi(3)); h=round(roi(4));
if x<1 || y<1 || x+w-1>size(I,2) || y+h-1>size(I,1), crop=[]; cancelled=true; return; end
crop=I(y:y+h-1,x:x+w-1,:);
end
