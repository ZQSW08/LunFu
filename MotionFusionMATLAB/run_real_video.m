function result=run_real_video(u)
% Resolve first-frame identity, measure, denoise without truth, export.
base=mfm.real_defaults();names=fieldnames(u);for j=1:numel(names),assert(isfield(base,names{j}),'Unknown public option');base.(names{j})=u.(names{j});end;u=base;
assert(isfile(u.videoPath),'Video not found');assert(~isempty(u.outputRoot),'Set outputRoot');
v=VideoReader(u.videoPath);im=readFrame(v);if size(im,3)==3,im=rgb2gray(im);end
[target,refs,provenance,model,samples,guide]=mfm.resolve_rois(u,im);
[~,name]=fileparts(u.videoPath);output=fullfile(u.outputRoot,name);
if isfolder(output)
    assert(isfile(fullfile(output,'.mfm_output')),'Existing directory is not a managed MFM run; use a different outputRoot');
    history=fullfile(u.outputRoot,'_history');if ~isfolder(history),mkdir(history);end
    movefile(output,fullfile(history,[name '_' datestr(now,'yyyymmdd_HHMMSSFFF')]));
end
c=mfm.defaults();c.video=u.videoPath;c.output=output;c.rois=[target;refs];c.fps=u.captureFPS;c.axis=u.axis;c.maxFrames=u.maxFrames;c.targetMode=u.targetMode;c.referenceModel=model;c.maxSamples=samples;c.guideMode=guide;c.autoProfileRows=u.autoProfileRows;c.fastSearch=true;
c.referenceTracker=u.referenceTracker;
c.referenceSelection=u.referenceSelection;autoFields={'automaticReferenceCount','automaticPatchSize','automaticReferenceAffine','automaticMinReferences','automaticMinInlierRatio','automaticConsensusTolerance','automaticMaxSpread','automaticAmbiguityRatio'};
for j=1:numel(autoFields),c.(autoFields{j})=u.(autoFields{j});end
result=run_measurement(c);fid=fopen(fullfile(output,'.mfm_output'),'w');fprintf(fid,'MotionFusionMATLAB managed output\n');fclose(fid);
result.roiProvenance=provenance;result.publicConfig=u;
ids=1;if strcmp(u.axis,'y'),ids=2;elseif strcmp(u.axis,'xy'),ids=1:2;end
tt=tic;
for axisId=ids
    key='x';if axisId==2,key='y';end
    result.signals.(key)=mfm.clean_signal(result.relative(:,axisId),result.fps,u.analysisBandHz,u.denoise);
end
result.postprocessSeconds=toc(tt);save(fullfile(output,'result.mat'),'-struct','result','-v7');
fid=fopen(fullfile(output,'roi_provenance.json'),'w');fwrite(fid,jsonencode(provenance,'PrettyPrint',true),'char');fclose(fid);
export_real_outputs(result,im,u.showFigures,u.exportFigures);
% Tracking-video rendering is an evidence export after measurement. Its time
% is kept separate from algorithmSeconds so speed comparisons remain honest.
result.trackingVideo=[];
if u.exportTrackingVideo
    trackingPath=fullfile(output,'tracking_overlay.avi');
    try
        result.trackingVideo=export_tracking_video(result,trackingPath);
    catch ex
        result.trackingVideo=struct('status','export_failed','path',trackingPath,...
            'error',ex.message,'framesWritten',0,'seconds',NaN);
        fid=fopen(fullfile(output,'tracking_video_error.txt'),'w');
        if fid>=0,fwrite(fid,getReport(ex));fclose(fid);end
    end
else
    result.trackingVideo=struct('status','disabled','path','','framesWritten',0,'seconds',0);
end
result.trackingVideoSeconds=result.trackingVideo.seconds;
save(fullfile(output,'result.mat'),'-struct','result','-v7');
fprintf('Measurement saved (not an accuracy certification): %s\n',output);
end
