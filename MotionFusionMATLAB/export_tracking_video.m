function meta=export_tracking_video(result,outputPath)
% Render tracked ROI positions from the saved per-frame displacement table.
% This is a visualization export and is deliberately timed separately from
% run_measurement's algorithmSeconds. It never changes the measured signal.
assert(isfield(result,'cfg')&&isfield(result.cfg,'video'),'Result has no source video');
assert(isfield(result,'displacements'),'Result has no displacement table');
v=VideoReader(result.cfg.video);fps=result.fps;if isempty(fps),fps=v.FrameRate;end
parent=fileparts(outputPath);if ~isfolder(parent),mkdir(parent);end
w=VideoWriter(outputPath,'Motion JPEG AVI');w.FrameRate=fps;w.Quality=95;open(w);
started=tic;k=0;fig=figure('Visible','off','Color','w','Position',[100 100 1100 700]);
cleanup=onCleanup(@()closeWriter());
while hasFrame(v)&&k<size(result.displacements,1)
    source=readFrame(v);if size(source,3)==3,gray=rgb2gray(source);else,gray=source;end
    k=k+1;imshow(gray,[],'Border','tight');hold on;
    for j=1:size(result.displacements,2)
        roi=result.cfg.rois(j,:);d=squeeze(result.displacements(k,j,:))';
        valid=all(isfinite(d));pos=roi;if valid,pos(1:2)=pos(1:2)+d;end
        if j==1,col=[0 .75 1];label='target';else,col=[1 .55 0];label=sprintf('ref%d',j-1);end
        style='-';if ~valid,style='--';end
        rectangle('Position',pos,'EdgeColor',col,'LineWidth',2,'LineStyle',style);
        text(pos(1),max(1,pos(2)-5),label,'Color',col,'FontWeight','bold','Interpreter','none');
    end
    title(sprintf('Tracked ROIs | frame %d/%d | t=%.3f s',k,size(result.displacements,1),result.time(k)));
    drawnow;fr=getframe(fig);writeVideo(w,fr.cdata);cla reset;
end
meta=struct('status','written','path',outputPath,'framesWritten',k,...
    'seconds',toc(started),'fps',fps,'sourceVideo',result.cfg.video,...
    'note','Overlay uses measured per-frame ROI displacements; it is not a second measurement.');
clear cleanup;
closeWriter();
    function closeWriter()
        try,close(w);catch,end
        if isvalid(fig),close(fig);end
    end
end
