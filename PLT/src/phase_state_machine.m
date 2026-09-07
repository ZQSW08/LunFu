function [state,center,status] = phase_state_machine(state,center,quality,cfg)
% PHASE_STATE_MACHINE 管理健康、弱跟踪和恢复状态。
% 低质量时冻结位置；只有 PHASE_TRACK_OK 才允许 V3 模板更新。
if ~isfinite(quality) || quality<cfg.method.minTrackingQuality
    center=state.previousCenter; state.lostCount=state.lostCount+1; status='PHASE_TRACK_WEAK';
else
    state.lostCount=0; status='PHASE_TRACK_OK';
end
if isfield(cfg.method,'recoveryAfterLostFrames') && state.lostCount>=cfg.method.recoveryAfterLostFrames
    status='PHASE_TRACK_RECOVERY';
end
state.previousCenter=center; state.status=status; state.lastQuality=quality;
end
