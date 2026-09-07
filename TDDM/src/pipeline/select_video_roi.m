function [roi,firstFrame,firstCrop,cancelled]=select_video_roi(videoPath,presetRoi,windowTitle)
%SELECT_VIDEO_ROI 在首帧框选固定 ROI，处理确认、关闭和取消。
if nargin<3, windowTitle='Select ROI'; end
v=VideoReader(videoPath); firstFrame=read(v,1); cancelled=false;
if ~isempty(presetRoi), [roi,firstCrop,cancelled]=local_crop(presetRoi,firstFrame); return; end
fig=figure('Name',windowTitle,'Color','w'); imshow(firstFrame,[]);
title('拖动矩形，双击或按 Enter 确认，关闭窗口取消'); h=drawrectangle('Color','r');
try, wait(h); catch, cancelled=true; end
if cancelled || ~isvalid(fig) || ~isvalid(h)
    if isvalid(fig), close(fig); end
    roi=[]; firstCrop=[]; cancelled=true; return;
end
roi=h.Position; close(fig); [roi,firstCrop,cancelled]=local_crop(roi,firstFrame);
end
function [roi,crop,cancelled]=local_crop(roi,I)
cancelled=false; roi=double(roi(:)');
if numel(roi)~=4, roi=[]; crop=[]; cancelled=true; return; end
x=max(1,round(roi(1))); y=max(1,round(roi(2)));
w=min(round(roi(3)),size(I,2)-x+1); h=min(round(roi(4)),size(I,1)-y+1);
if w<8 || h<8, roi=[]; crop=[]; cancelled=true; return; end
roi=[x y w h]; crop=I(y:y+h-1,x:x+w-1,:);
end
