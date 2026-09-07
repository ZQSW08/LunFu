function [crop,roi] = crop_square_from_frame(frame,center,side)
%CROP_SQUARE_FROM_FRAME 以全局中心更新方形 ROI，并限制在图像边界内。
[h,w,~]=size(frame); side=min([round(side),h,w]);
x=round(center(1)-side/2); y=round(center(2)-side/2);
x=min(max(1,x),w-side+1); y=min(max(1,y),h-side+1); roi=[x y side side];
crop=frame(y:y+side-1,x:x+side-1,:);
end
