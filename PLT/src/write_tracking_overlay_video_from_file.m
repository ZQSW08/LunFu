function actualPath=write_tracking_overlay_video_from_file(videoPath,centers,roi,fps,outPath,lineColor,labelText)
% WRITE_TRACKING_OVERLAY_VIDEO_FROM_FILE 第二次顺序读取视频并写入跟踪标注过程。
% 这样真实视频不需要把全部帧一次性放入内存；MPEG-4 失败时安全回退 AVI。

if nargin<6 || isempty(lineColor), lineColor=[1 0 0]; end
if nargin<7 || isempty(labelText), labelText='tracking'; end

actualPath=outPath;
try
    write_video_once(videoPath,centers,roi,fps,outPath,'MPEG-4',lineColor,labelText);
catch
    if isfile(outPath), delete(outPath); end
    actualPath=strrep(outPath,'.mp4','.avi'); write_video_once(videoPath,centers,roi,fps,actualPath,'Motion JPEG AVI',lineColor,labelText);
end
end

function write_video_once(videoPath,centers,roi,fps,outPath,profile,lineColor,labelText)
writer=VideoWriter(outPath,profile); writer.FrameRate=fps; open(writer); fig=figure('Visible','off','Color','w'); vr=VideoReader(videoPath); k=0;
try
    while hasFrame(vr) && k<size(centers,1)
        k=k+1; frame=readFrame(vr); imshow(frame); hold on;
        position=[centers(k,1)-roi(3)/2+0.5,centers(k,2)-roi(4)/2+0.5,roi(3),roi(4)];
        rectangle('Position',position,'EdgeColor',lineColor,'LineWidth',1.5);
        plot(centers(k,1),centers(k,2),'+','Color',lineColor,'MarkerSize',8,'LineWidth',1.2);
        text(position(1),max(1,position(2)-5),labelText,'Color',lineColor,'FontWeight','bold','FontSize',10); hold off;
        writeVideo(writer,getframe(fig));
    end
    close(writer); close(fig);
catch err
    close(writer); close(fig); rethrow(err);
end
end
