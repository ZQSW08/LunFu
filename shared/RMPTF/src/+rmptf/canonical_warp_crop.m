function crop = canonical_warp_crop(frame, pose, outputSize, interpolation)
%CANONICAL_WARP_CROP 可选规范化仿射裁剪，仅供插值偏差对照，默认主链路禁用。
if nargin<4 || isempty(interpolation), interpolation='bilinear'; end
if numel(outputSize)~=2, error('outputSize 必须为 [height width]。'); end
center=double(pose.centerXY); scale=double(pose.scale); angle=double(pose.rotationDeg);
theta=deg2rad(angle); rotation=[cos(theta) -sin(theta);sin(theta) cos(theta)];
[xx,yy]=meshgrid((1:outputSize(2))-0.5*(outputSize(2)+1), ...
    (1:outputSize(1))-0.5*(outputSize(1)+1));
source=scale*(rotation*[xx(:).';yy(:).']);
xq=reshape(source(1,:)+center(1),outputSize); yq=reshape(source(2,:)+center(2),outputSize);
crop=interp2(single(frame),xq,yq,interpolation,0);
end
