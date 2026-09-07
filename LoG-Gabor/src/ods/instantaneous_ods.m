function result = instantaneous_ods(displacement, frameIndex)
%INSTANTANEOUS_ODS 论文 cable 实验中的瞬时 ODS：保留当前帧正负方向。
if nargin<2 || isempty(frameIndex), frameIndex=size(displacement,3); end
frameIndex=min(max(1,frameIndex),size(displacement,3));
field=displacement(:,:,frameIndex);
result.field=field;
result.amplitude=abs(field);
result.frameIndex=frameIndex;
result.normalized=(field-min(field(:)))/(max(field(:))-min(field(:))+eps);
end
