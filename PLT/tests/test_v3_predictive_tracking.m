function result=test_v3_predictive_tracking()
% TEST_V3_PREDICTIVE_TRACKING 验证 V3 预测、模板更新和 POC 恢复。
% 这是带真值的等价验证，不宣称替代真实结构视频实验。
cfg=default_config(); cfg.method.observedAxis='x'; cfg.method.localSearchRadiusPx=6;
cfg.method.recoveryAfterLostFrames=2; cfg.method.templateUpdateMinQuality=0.30;
cfg.method.minTrackingQuality=0.30;
cfg.method.templateUpdateIntervalFrames=4; cfg.video.maxFrames=45;
[frames,trueCenters,roi]=make_v3_sequence(cfg.video.maxFrames);
state=initialize_phase_tracker(frames{1},roi,cfg); n=numel(frames);
centers=nan(n,2); valid=false(n,1); usedPrediction=false(n,1); usedRecovery=false(n,1); updated=false(n,1);
centers(1,:)=state.anchor.center; valid(1)=true; timer=tic;
for k=2:n
    pyramid=build_complex_gabor_pyramid(frames{k},cfg);
    [state,out]=track_one_frame(state,frames{k},cfg,'v3_predictive',pyramid);
    centers(k,:)=out.center; valid(k)=out.valid; usedPrediction(k)=out.usedPrediction;
    usedRecovery(k)=out.usedPocRecovery; updated(k)=out.templateUpdated;
end
runtime=toc(timer); errorPx=sqrt(sum((centers-trueCenters).^2,2)); finite=isfinite(errorPx);
result=struct('medianCenterErrorPx',median(errorPx(finite)),'lostRate',1-mean(valid),...
    'recoveryCount',sum(usedRecovery),'predictionRate',mean(usedPrediction),...
    'templateUpdateCount',sum(updated),'runtimeS',runtime,'frames',n,'passed',false);
% 至少验证预测路径被使用，且故障帧后发生过恢复；误差阈值只用于发现明显失锁。
fprintf('V3 predictive check: median error=%.3f px, lost rate=%.1f%%, recoveries=%d, updates=%d\n',...
    result.medianCenterErrorPx,100*result.lostRate,result.recoveryCount,result.templateUpdateCount);
result.passed=result.medianCenterErrorPx<=4 && result.recoveryCount>=1 && result.predictionRate>0.5;
assert(result.passed,'V3 predictive tracking validation failed.');
end

function [frames,centers,roi]=make_v3_sequence(n)
rng(31,'twister'); H=260; W=420; h=72; w=92; x0=150; y0=82;
background=normalize_v3(0.7*conv2(randn(H,W),ones(7,7)/49,'same')+0.3*rand(H,W));
target=normalize_v3(0.8*conv2(randn(h,w),ones(5,5)/25,'same')+0.2*rand(h,w));
[xx,yy]=meshgrid(1:w,1:h); target=normalize_v3(target+0.08*sin(xx/4.1)+0.05*cos((xx+yy)/7.3));
frames=cell(n,1); centers=zeros(n,2); roi=[x0 y0 w h];
for k=1:n
    dx=round(0.9*(k-1)); if k>=24, dx=dx+15; end
    dy=round(2*sin(2*pi*0.25*(k-1)/n)); x=x0+dx; y=y0+dy;
    frame=background;
    if k~=24 && k~=25, frame(y:y+h-1,x:x+w-1)=target; end
    frames{k}=uint8(255*frame);
    centers(k,:)=[x+(w-1)/2,y+(h-1)/2];
end
end
function img=normalize_v3(img)
img=double(img); img=img-min(img(:)); img=img/max(max(img(:)),eps);
end
