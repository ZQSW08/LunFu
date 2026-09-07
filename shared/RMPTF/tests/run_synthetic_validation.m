function metrics = run_synthetic_validation(outputRoot, compensationMode, macroFrequency)
%RUN_SYNTHETIC_VALIDATION 验证大运动、微振动、遮挡恢复与十字相位定位。
if nargin<1 || isempty(outputRoot)
    outputRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))),'outputs','synthetic_validation');
end
if nargin<2 || isempty(compensationMode), compensationMode='band_protected'; end
if nargin<3 || isempty(macroFrequency), macroFrequency=0.35; end
if ~isfolder(outputRoot), mkdir(outputRoot); end
rmptfRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(rmptfRoot,'src'));

rng(20260902);
fps=60; frameCount=180; imageSize=[240 320]; baseCenter=[160 120];
time=(0:frameCount-1)'/fps;
macroX=55*sin(2*pi*macroFrequency*time);
macroY=28*(sin(2*pi*0.23*time+0.4)-sin(0.4));
microFrequency=6.7;
microX=0.35*sin(2*pi*microFrequency*time+0.2);
truthCenter=[baseCenter(1)+macroX+microX,baseCenter(2)+macroY];
occluded=false(frameCount,1); occluded(80:90)=true;
videoPath=fullfile(outputRoot,'large_motion_crossline_truth.avi');
localWriteSyntheticVideo(videoPath,truthCenter,occluded,imageSize,fps,baseCenter);

initialRoi=[baseCenter-[48 48] 96 96];
cfg=rmptf.default_config();
cfg.tracker.searchRadiusPx=44; cfg.tracker.redetectRadiusPx=120;
cfg.tracker.maxStepPixels=45; cfg.tracker.predictFrames=3; cfg.tracker.globalRedetectAfter=6;
cfg.tracker.scaleFactors=[0.97 1 1.03];
cfg.compensation.mode=compensationMode; cfg.compensation.cutoffHz=1;
cfg.compensation.targetBandHz=[5 8]; cfg.compensation.trackingAxis='xy';
cfg.phaseCrossline.enabled=true; cfg.phaseCrossline.wavelength=12;
cfg.phaseCrossline.sigma=5; cfg.phaseCrossline.minimumQuality=0.18;
cfg.phaseCrossline.maximumCorrectionPx=28;
[~,processingFps,roiTrajectory,tracking]=rmptf.process_video(videoPath,frameCount,initialRoi,cfg,'');

evaluation=~occluded & tracking.valid;
trackingError=hypot(tracking.center(:,1)-truthCenter(:,1),tracking.center(:,2)-truthCenter(:,2));
phaseValid=~occluded & tracking.crosslineQuality>0 & all(isfinite(tracking.crosslineCenter),2);
phaseError=hypot(tracking.crosslineCenter(:,1)-truthCenter(:,1),tracking.crosslineCenter(:,2)-truthCenter(:,2));
cropDisplacement=tracking.coarseDisplacement;
truthDisplacement=truthCenter-truthCenter(1,:);
residualX=truthDisplacement(:,1)-cropDisplacement(:,1);
% 联合回归宏/微频率，避免有限时长下非整周期宏观分量泄漏到 6 Hz 指标。
macroResidual=localHarmonicAmplitude(residualX(evaluation),time(evaluation),macroFrequency,microFrequency);
microResidual=localHarmonicAmplitude(residualX(evaluation),time(evaluation),microFrequency,macroFrequency);
macroSuppression=1-macroResidual/55;
vibrationPreservation=microResidual/0.35;
maximumResidual=max(abs(residualX(evaluation)));
afterOcclusion=find(tracking.valid(91:end),1,'first');
if isempty(afterOcclusion), recoveryFrames=Inf; else, recoveryFrames=afterOcclusion-1; end

metrics=table(processingFps,mean(tracking.valid),median(trackingError(evaluation)), ...
    prctile(trackingError(evaluation),95),mean(phaseValid),median(phaseError(phaseValid),'omitnan'), ...
    recoveryFrames,macroSuppression,vibrationPreservation,maximumResidual, ...
    'VariableNames',{'fps','valid_fraction','median_tracking_error_px','p95_tracking_error_px', ...
    'crossline_valid_fraction','median_crossline_error_px','recovery_frames', ...
    'macro_suppression_ratio','vibration_preservation_ratio','maximum_residual_px'});
writetable(metrics,fullfile(outputRoot,'validation_metrics.csv'));
trajectory=table(time,truthCenter(:,1),truthCenter(:,2),tracking.center(:,1),tracking.center(:,2), ...
    tracking.quality,tracking.valid,string(tracking.state),tracking.redetectionUsed, ...
    tracking.crosslineCenter(:,1),tracking.crosslineCenter(:,2),tracking.crosslineQuality, ...
    roiTrajectory(:,1),roiTrajectory(:,2),cropDisplacement(:,1),cropDisplacement(:,2), ...
    'VariableNames',{'time_s','truth_x','truth_y','track_x','track_y','quality','valid','state', ...
    'redetect','phase_cross_x','phase_cross_y','phase_cross_quality','crop_x','crop_y', ...
    'crop_displacement_x','crop_displacement_y'});
writetable(trajectory,fullfile(outputRoot,'tracking_trajectory.csv'));

fig=figure('Visible','off','Color','w','Position',[100 100 1100 780]);
subplot(3,1,1); plot(time,truthCenter(:,1),'k','LineWidth',1.2); hold on;
plot(time,tracking.center(:,1),'Color',[0 0.45 0.74]); plot(time,roiTrajectory(:,1)+initialRoi(3)/2,'--','Color',[0.85 0.33 0.10]);
ylabel('x (px)'); legend('truth','RMPTF raw','integer crop','Location','best'); grid on;
subplot(3,1,2); plot(time,tracking.quality,'k'); hold on; stairs(time,double(~tracking.valid),'r');
stairs(time,double(tracking.redetectionUsed),'Color',[0.47 0.67 0.19]); ylabel('quality / event'); grid on;
legend('quality','invalid','redetect','Location','best');
subplot(3,1,3); plot(time,residualX,'Color',[0.49 0.18 0.56]); hold on; plot(time,microX,'k--');
xlabel('Time (s)'); ylabel('residual x (px)'); legend('after crop','true micro','Location','best'); grid on;
exportgraphics(fig,fullfile(outputRoot,'validation_overview.png'),'Resolution',180); close(fig);
save(fullfile(outputRoot,'validation_result.mat'),'metrics','tracking','truthCenter','time','occluded','cfg');

assert(metrics.valid_fraction>0.70,'RMPTF 有效帧比例未达到合成验证下限。');
assert(metrics.median_tracking_error_px<12,'RMPTF 合成序列中位跟踪误差过大。');
assert(metrics.macro_suppression_ratio>0.55,'宏观运动抑制不足。');
assert(metrics.maximum_residual_px<6,'短序列端点或遮挡恢复后的残余大运动过大。');
assert(metrics.vibration_preservation_ratio>0.35 && metrics.vibration_preservation_ratio<1.8, ...
    '微振动保持比例异常。');
if nnz(phaseValid)>=20
    assert(metrics.median_crossline_error_px<8,'十字相位交点定位误差过大。');
end
disp(metrics);
end

function localWriteSyntheticVideo(pathValue,truthCenter,occluded,imageSize,fps,baseCenter)
writer=VideoWriter(pathValue,'Motion JPEG AVI'); writer.FrameRate=fps; writer.Quality=95; open(writer);
[xx,yy]=meshgrid(1:imageSize(2),1:imageSize(1));
background=0.13+0.025*randn(imageSize)+0.03*sin(0.07*xx+0.04*yy);
patchSize=81; [px,py]=meshgrid(1:patchSize,1:patchSize);
texture=0.30+0.16*rand(patchSize)+0.08*sin(0.24*px).*cos(0.19*py);
center=(patchSize+1)/2;
crossMask=abs(px-center)<=2 | abs(py-center)<=2;
texture(crossMask)=0.98;
edgeMask=(px-1).*(patchSize-px).*(py-1).*(patchSize-py)>0;
mask=single(edgeMask); target=single(texture).*mask;
baseTopLeft=round(baseCenter-[center center])+1;
targetCanvas=zeros(imageSize,'single'); maskCanvas=zeros(imageSize,'single');
rows=baseTopLeft(2)+(0:patchSize-1); cols=baseTopLeft(1)+(0:patchSize-1);
targetCanvas(rows,cols)=target; maskCanvas(rows,cols)=mask;
for k=1:size(truthCenter,1)
    shift=truthCenter(k,:)-baseCenter;
    movedTarget=imtranslate(targetCanvas,shift,'linear','OutputView','same','FillValues',0);
    movedMask=imtranslate(maskCanvas,shift,'linear','OutputView','same','FillValues',0);
    frame=single(background).*(1-movedMask)+movedTarget;
    frame=frame+0.008*randn(imageSize,'single');
    if occluded(k)
        cx=round(truthCenter(k,1)); cy=round(truthCenter(k,2));
        x1=max(1,cx-50); x2=min(imageSize(2),cx+50); y1=max(1,cy-50); y2=min(imageSize(1),cy+50);
        frame(y1:y2,x1:x2)=0.12+0.02*randn(y2-y1+1,x2-x1+1,'single');
    end
    writeVideo(writer,uint8(255*min(max(frame,0),1)));
end
close(writer);
end

function amplitude=localHarmonicAmplitude(signal,time,frequency,nuisanceFrequency)
design=[sin(2*pi*frequency*time) cos(2*pi*frequency*time) ...
    sin(2*pi*nuisanceFrequency*time) cos(2*pi*nuisanceFrequency*time) ...
    ones(size(time)) time];
coefficients=design\double(signal(:)); amplitude=hypot(coefficients(1),coefficients(2));
end
