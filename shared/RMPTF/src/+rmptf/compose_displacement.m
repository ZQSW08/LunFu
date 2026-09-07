function globalDisplacement = compose_displacement(localDisplacement, cropDisplacement, axisName)
%COMPOSE_DISPLACEMENT 恢复全局坐标：动态裁剪整数位移 + 后端局部残差。
if nargin<3 || isempty(axisName), axisName='x'; end
axisIndex=1+strcmpi(char(axisName),'y');
if size(cropDisplacement,2)~=2, error('cropDisplacement 必须为 N x 2。'); end
if numel(localDisplacement)~=size(cropDisplacement,1), error('局部位移与裁剪轨迹长度不一致。'); end
globalDisplacement=double(localDisplacement(:))+double(cropDisplacement(:,axisIndex));
end
