function globalDisplacement = compose_similarity_displacement(localPoint, cropPose, referencePoint)
%COMPOSE_SIMILARITY_DISPLACEMENT 用完整相似变换恢复全局点位移。
% localPoint: N x 2，在规范化/动态裁剪坐标中的测量点；
% cropPose:   struct，字段 translationXY(Nx2), scale(Nx1), rotationDeg(Nx1)；
% referencePoint: 1 x 2，首帧局部坐标。平移-only 是本函数的特例。
if nargin<3 || isempty(referencePoint), referencePoint=double(localPoint(1,:)); end
localPoint=double(localPoint);
n=size(localPoint,1);
required={'translationXY','scale','rotationDeg'};
for k=1:numel(required)
    if ~isfield(cropPose,required{k}), error('cropPose 缺少字段 %s。',required{k}); end
end
translation=double(cropPose.translationXY);
scale=double(cropPose.scale(:)); angle=deg2rad(double(cropPose.rotationDeg(:)));
if size(translation,1)~=n || numel(scale)~=n || numel(angle)~=n
    error('localPoint 与 cropPose 长度不一致。');
end
globalPoint=zeros(n,2);
for i=1:n
    rotation=[cos(angle(i)) -sin(angle(i)); sin(angle(i)) cos(angle(i))];
    globalPoint(i,:)=translation(i,:)+(scale(i)*(rotation*localPoint(i,:).')).';
end
referenceGlobal=translation(1,:)+(scale(1)*([cos(angle(1)) -sin(angle(1));sin(angle(1)) cos(angle(1))]*referencePoint(:))).';
globalDisplacement=globalPoint-referenceGlobal;
end
