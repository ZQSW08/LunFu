function [cropBbox, actualDisplacement, boundary] = phase_safe_crop(initialRoi, macroDisplacement, imageSize)
%PHASE_SAFE_CROP 只用整数像素平移固定尺寸 ROI，避免插值改变相位。
% imageSize=[height width]；actualDisplacement 反映触边后真正执行的裁剪位移。
roi=round(double(initialRoi)); imageSize=double(imageSize(:)');
n=size(macroDisplacement,1); cropBbox=zeros(n,4); boundary=false(n,1);
for k=1:n
    proposed=[roi(1:2)+round(macroDisplacement(k,:)),roi(3:4)];
    clamped=localClamp(proposed,imageSize(2),imageSize(1));
    cropBbox(k,:)=clamped;
    boundary(k)=any(clamped(1:2)~=proposed(1:2));
end
actualDisplacement=cropBbox(:,1:2)-cropBbox(1,1:2);
end

function bbox=localClamp(bbox,w,h)
bbox=round(double(bbox));
bbox(3)=min(max(2,bbox(3)),w); bbox(4)=min(max(2,bbox(4)),h);
bbox(1)=min(max(1,bbox(1)),max(1,w-bbox(3)+1));
bbox(2)=min(max(1,bbox(2)),max(1,h-bbox(4)+1));
end
