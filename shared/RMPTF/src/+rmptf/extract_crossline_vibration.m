function result = extract_crossline_vibration(crosslineCenter, cropDisplacement, valid, fps, axisName, targetBandHz)
%EXTRACT_CROSSLINE_VIBRATION 十字相位交点的直接微振动测量候选，不替代论文后端。
if nargin<5 || isempty(axisName), axisName='x'; end
if nargin<6, targetBandHz=[]; end
axisIndex=1+strcmpi(char(axisName),'y'); center=double(crosslineCenter(:,axisIndex));
valid=logical(valid(:))&isfinite(center); repaired=center; repaired(~valid)=NaN;
if nnz(valid)>=2, repaired=fillmissing(repaired,'linear','EndValues','nearest');
elseif nnz(valid)==1, repaired(:)=repaired(find(valid,1)); else, repaired(:)=0; end
raw=repaired-repaired(1); residual=raw-double(cropDisplacement(:,axisIndex)); filtered=residual;
if ~isempty(targetBandHz) && numel(targetBandHz)==2 && targetBandHz(2)<fps/2
    try
        [b,a]=butter(4,sort(double(targetBandHz))/(fps/2),'bandpass'); filtered=filtfilt(b,a,residual);
    catch
        % 无 Signal Processing Toolbox 时保留未滤波相位交点残差。
    end
end
result=struct('rawDisplacementPx',raw,'residualPx',residual,'bandPassedPx',filtered, ...
    'valid',valid,'axis',char(axisName),'targetBandHz',targetBandHz);
end
