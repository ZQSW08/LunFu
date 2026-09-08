function meta=export_tracking_video(result,outputPath)
% Write one tracking-overlay video by painting pixels directly into frames.
% No figure, imshow, drawnow, or getframe is used. The export is timed
% separately from run_measurement's algorithmSeconds and never changes the
% measured signal.
assert(isfield(result,'cfg')&&isfield(result.cfg,'video'),'Result has no source video');
assert(isfield(result,'displacements'),'Result has no displacement table');
v=VideoReader(result.cfg.video);fps=result.fps;if isempty(fps),fps=v.FrameRate;end
parent=fileparts(outputPath);if ~isfolder(parent),mkdir(parent);end
w=VideoWriter(outputPath,'Motion JPEG AVI');w.FrameRate=fps;w.Quality=95;open(w);
started=tic;k=0;frameCount=size(result.displacements,1);cleanup=onCleanup(@closeWriter);
while hasFrame(v)&&k<frameCount
    frame=readFrame(v);frame=toRGBuint8(frame);k=k+1;
    for j=1:size(result.displacements,2)
        roi=result.cfg.rois(j,:);d=squeeze(result.displacements(k,j,:))';
        valid=all(isfinite(d));pos=roi;if valid,pos(1:2)=pos(1:2)+d;end
        if j==1,col=uint8([0 191 255]);else,col=uint8([255 140 0]);end
        frame=paintRect(frame,pos,col,valid);
    end
    writeVideo(w,frame);
end
meta=struct('status','written','path',outputPath,'framesWritten',k,...
    'seconds',toc(started),'fps',fps,'sourceVideo',result.cfg.video,...
    'note','Overlay is painted directly into video frames; it is not a second measurement and no figure is created.');
clear cleanup;
closeWriter();
    function closeWriter()
        try,close(w);catch,end
    end
end

function frame=toRGBuint8(frame)
if isfloat(frame)
    if isempty(frame),return;end
    if max(frame(:),[],'omitnan')<=1,frame=uint8(max(0,min(1,frame))*255);
    else,frame=uint8(max(0,min(255,frame)));end
elseif ~isa(frame,'uint8')
    frame=uint8(frame);
end
if ndims(frame)==2,frame=repmat(frame,1,1,3);elseif size(frame,3)>3,frame=frame(:,:,1:3);end
end

function frame=paintRect(frame,pos,col,valid)
H=size(frame,1);W=size(frame,2);
x1=max(1,min(W,round(pos(1))));y1=max(1,min(H,round(pos(2))));
x2=max(1,min(W,round(pos(1)+pos(3)-1)));y2=max(1,min(H,round(pos(2)+pos(4)-1)));
if x2<x1||y2<y1,return;end
width=2;
frame=paintLine(frame,x1,x2,y1,col,valid,width,false);
frame=paintLine(frame,x1,x2,y2,col,valid,width,false);
frame=paintLine(frame,y1,y2,x1,col,valid,width,true);
frame=paintLine(frame,y1,y2,x2,col,valid,width,true);
end

function frame=paintLine(frame,a,b,fixed,col,solid,width,vertical)
if solid,starts=1;step=max(1,b-a+1);else,starts=1:8:(b-a+1);step=4;end
for q=starts
    e=min(q+step-1,b-a+1);idx=a+q-1:a+e-1;
    if vertical,rows=idx;cols=max(1,fixed-width+1):min(size(frame,2),fixed+width-1);
    else,rows=max(1,fixed-width+1):min(size(frame,1),fixed+width-1);cols=idx;end
    for c=1:3,frame(rows,cols,c)=col(c);end
end
end
