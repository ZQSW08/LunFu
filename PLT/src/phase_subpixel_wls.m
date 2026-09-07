function sub = phase_subpixel_wls(template,pyramid,integerCenter,cfg)
% PHASE_SUBPIXEL_WLS 用多通道相位差的加权最小二乘估计亚像素残差。
% 对应报告中的 Delta phi ~= K*delta；不对 wrapped phase angle 做插值。

roi=template.roi; w=roi(3); h=roi(4);
topLeft=[round(integerCenter(1)-floor((w-1)/2)),round(integerCenter(2)-floor((h-1)/2))];
K=[]; deltaPhi=[]; weights=[];
if isfield(cfg.method,'measurementScaleIndices'), scaleIndices=cfg.method.measurementScaleIndices; else, scaleIndices=1:size(template.channels,1); end
if isfield(cfg.method,'measurementOrientationIndices'), orientationIndices=cfg.method.measurementOrientationIndices; else, orientationIndices=1:size(template.channels,2); end
for s=scaleIndices
    for o=orientationIndices
        if ~is_valid_patch(topLeft,[w h],size(pyramid(s,o).phase)), continue; end
        channel=template.channels(s,o);
        currentZ=crop_matrix(pyramid(s,o).unitPhasor,topLeft,[w h]);
        currentAmp=crop_matrix(pyramid(s,o).amplitude,topLeft,[w h]);
        dphi=angle(conj(channel.unitPhasor).*currentZ);
        ampWeight=2*channel.amplitude.*currentAmp./(channel.amplitude.^2+currentAmp.^2+eps);
        valid=channel.reliability & crop_matrix(pyramid(s,o).reliability,topLeft,[w h]);
        valid=valid & isfinite(dphi) & ampWeight>0;
        if ~any(valid(:)), continue; end
        wavevector=pyramid(s,o).wavevector;
        K=[K;repmat(wavevector,sum(valid(:)),1)]; %#ok<AGROW>
        deltaPhi=[deltaPhi;dphi(valid)]; %#ok<AGROW>
        weights=[weights;ampWeight(valid)]; %#ok<AGROW>
    end
end

sub=struct('delta',[0 0],'valid',false,'residualRms',NaN,'sampleCount',numel(deltaPhi));
% ROI 靠近边界、纹理过弱或候选 patch 不完整时可能没有有效相位样本。
% 此时亚像素残差应安全返回无效，而不是对空 K 做列索引。
if isempty(K) || size(K,2)<2 || isempty(weights) || numel(weights)~=size(K,1)
    return;
end
finiteRows=all(isfinite(K),2) & isfinite(deltaPhi(:)) & isfinite(weights(:)) & weights(:)>0;
K=K(finiteRows,:); deltaPhi=deltaPhi(finiteRows); weights=weights(finiteRows);
sub.sampleCount=numel(deltaPhi);
if isempty(K), return; end
if isfield(cfg.method,'observedAxis') && any(strcmpi(cfg.method.observedAxis,{'x','y'}))
    % 单方向观测只估计对应分量，避免把非观测方向的噪声带入输出。
    axisIndex=1+strcmpi(cfg.method.observedAxis,'y');
    kAxis=K(:,axisIndex); W=weights(:); denominator=sum(W.*kAxis.^2);
    if denominator<=eps, return; end
    deltaAxis=sum(W.*kAxis.*deltaPhi)/denominator; delta=[0 0]; delta(axisIndex)=deltaAxis;
    if norm(delta)>cfg.method.subpixelMaxPx
        sub.residualRms=sqrt(mean(deltaPhi.^2)); return;
    end
    sub.delta=delta; sub.valid=true;
    sub.residualRms=sqrt(mean((deltaPhi-kAxis*deltaAxis).^2)); return;
end
if size(K,1)<3 || rank(K)<2, return; end
W=weights(:); normal=K'*(W.*K); delta=normal\(K'*(W.*deltaPhi));
if norm(delta)>cfg.method.subpixelMaxPx
    sub.residualRms=sqrt(mean(deltaPhi.^2)); return;
end
sub.delta=delta(:).'; sub.valid=true;
sub.residualRms=sqrt(mean((deltaPhi-K*delta(:)).^2));
end

function ok=is_valid_patch(topLeft,patchSize,imageSize)
ok=topLeft(1)>=1 && topLeft(2)>=1 && topLeft(1)+patchSize(1)-1<=imageSize(2) && ...
    topLeft(2)+patchSize(2)-1<=imageSize(1);
end

function patch=crop_matrix(matrix,topLeft,patchSize)
x=topLeft(1); y=topLeft(2); w=patchSize(1); h=patchSize(2);
patch=matrix(y:y+h-1,x:x+w-1);
end
