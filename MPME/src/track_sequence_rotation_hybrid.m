function [transforms,diagnostics,coarseSteps,coarseTracking] = ...
    track_sequence_rotation_hybrid(frames,params,coarseOptions)
%TRACK_SEQUENCE_ROTATION_HYBRID 刚体粗转角与 M-PME 小残差的两阶段旋转估计。
% 稠密光流或 KLT 只提供相邻帧的大转角初值；每对帧先按该角度对齐，再用
% 一参数旋转相位模型估计残差，不用粗跟踪替代 M-PME 的精细测量。

if ~isfield(params,'rigidCenter') || isempty(params.rigidCenter)
    error('混合旋转跟踪必须提供 params.rigidCenter。');
end
if isfield(coarseOptions,'coarseMethod') && strcmpi(coarseOptions.coarseMethod,'flow')
    [~,coarseSteps,coarseTracking] = track_rotation_flow_rigid( ...
        frames,params.rigidCenter,coarseOptions);
else
    [~,coarseSteps,coarseTracking] = track_rotation_klt_rigid( ...
        frames,params.rigidCenter,coarseOptions);
end
frameCount = size(frames,3);
transforms = repmat(eye(3),1,1,frameCount);
diagnostics = cell(frameCount,1);

for frameIndex = 2:frameCount
    coarseStep = localRigidTransform(coarseSteps(frameIndex),params.rigidCenter);
    [coarseAligned,validWarp] = warp_image_h( ...
        frames(:,:,frameIndex),coarseStep,median(frames(:,:,frameIndex),'all'));
    residualParams = params;
    if isfield(residualParams,'mask') && ~isempty(residualParams.mask)
        residualParams.mask = residualParams.mask & validWarp;
    else
        residualParams.mask = validWarp;
    end
    [residualStep,phaseDiagnostics] = mpme_estimate_affine( ...
        frames(:,:,frameIndex-1),coarseAligned,residualParams);
    fullStep = coarseStep*residualStep;
    transforms(:,:,frameIndex) = fullStep*transforms(:,:,frameIndex-1);
    diagnostics{frameIndex} = struct('coarseStepDegrees',coarseSteps(frameIndex), ...
        'phaseResidualDegrees',atan2d(residualStep(2,1),residualStep(1,1)), ...
        'phase',phaseDiagnostics);
end
end

function transform = localRigidTransform(angleDeg,centre)
angleRad = deg2rad(angleDeg);
rotation = [cos(angleRad) -sin(angleRad); sin(angleRad) cos(angleRad)];
centreColumn = centre(:);
translation = centreColumn-rotation*centreColumn;
transform = [rotation translation; 0 0 1];
end
