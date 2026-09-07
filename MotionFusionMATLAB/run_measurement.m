function result=run_measurement(cfg)
% RUN_MEASUREMENT Streaming MATLAB measurement, no Python bridge.
% Target first, then non-vibrating rigid references. Output pixel units.
base=mfm.defaults();names=fieldnames(cfg);for j=1:numel(names),base.(names{j})=cfg.(names{j});end;cfg=base;
assert(size(cfg.rois,1)>=1,'At least one target ROI is required');
assert(strcmp(cfg.referenceModel,'none')||size(cfg.rois,1)>=2,'Reference-relative measurement requires explicit reference ROIs');
assert(~strcmp(cfg.referenceModel,'none')||size(cfg.rois,1)==1,'none requires target ROI only');
assert(any(strcmp(cfg.targetMode,{'profile','consensus','direct','texture'})),'Unknown targetMode');
assert(any(strcmp(cfg.referenceTracker,{'anchor','tiles','flow'})),'Unknown referenceTracker');
assert(any(strcmp(cfg.referenceSelection,{'manual','interactive','automatic'})),'Unknown referenceSelection');
automaticReference=strcmp(cfg.referenceSelection,'automatic');
if automaticReference,assert(strcmp(cfg.referenceModel,'translation')&&size(cfg.rois,1)-1>=cfg.automaticMinReferences,'Automatic references require robust translation and enough selected patches');end
assert(any(strcmp(cfg.axis,{'x','y','xy'})),'axis must be x/y/xy');
isProfile=any(strcmp(cfg.targetMode,{'profile','consensus','direct'}));
assert(~(strcmp(cfg.axis,'xy')&&isProfile),'Use texture for independent xy measurement');
originalCfg=cfg;transposeInput=strcmp(cfg.axis,'y');
if transposeInput,cfg.rois=cfg.rois(:,[2 1 4 3]);end
assert(~isempty(cfg.output)&&~isfolder(cfg.output),'Choose a new output directory');mkdir(cfg.output);
v=VideoReader(cfg.video);fps=cfg.fps;if isempty(fps),fps=v.FrameRate;end
assert(isfinite(fps)&&fps>0,'Invalid FPS');nr=size(cfg.rois,1);alloc=min(ceil(v.Duration*v.FrameRate)+10,cfg.maxFrames);
d=nan(alloc,nr,2);valid=false(alloc,nr);ncc=nan(alloc,nr);err=ncc;macro=nan(alloc,2);relative=macro;body=macro;centroid=nan(alloc,1);geom=false(alloc,1);
readSeconds=0;trackSeconds=0;k=0;started=tic;
profileScale=nan(alloc,1);profileShift=nan(alloc,1);
support=nan(alloc,nr);spread=support;reason=strings(alloc,nr);lastGuide=[0 0];
referenceInliers=false(alloc,max(0,nr-1));referenceSupport=zeros(alloc,1);referenceSpread=nan(alloc,1);referenceStatus=repmat("not_applicable",alloc,1);
while hasFrame(v)&&k<cfg.maxFrames
    tt=tic;im=readFrame(v);if size(im,3)==3,im=rgb2gray(im);end;sourceImage=im;if transposeInput,im=im';end;readSeconds=readSeconds+toc(tt);tt=tic;k=k+1;
    if k==1
        trackers=cell(nr,1);
        for j=2:nr
            if strcmp(cfg.referenceTracker,'tiles'),trackers{j}=mfm.TileReference(im,cfg.rois(j,:),cfg);
            elseif strcmp(cfg.referenceTracker,'flow'),trackers{j}=mfm.FlowReference(im,cfg.rois(j,:),cfg);
            else,trackers{j}=mfm.Tracker(im,cfg.rois(j,:),cfg);end
        end
        if strcmp(cfg.targetMode,'consensus'),trackers{1}=mfm.ConsensusProfile(im,cfg.rois(1,:),cfg);
        elseif strcmp(cfg.targetMode,'direct'),trackers{1}=mfm.DirectProfile(im,cfg.rois(1,:),cfg);
        elseif isProfile,trackers{1}=mfm.Profile(im,cfg.rois(1,:),cfg);
        else,trackers{1}=mfm.Tracker(im,cfg.rois(1,:),cfg);end
        d(k,:,:)=0;valid(k,:)=true;ncc(k,:)=1;err(k,:)=0;macro(k,:)=0;relative(k,:)=0;body(k,:)=0;centroid(k)=0;geom(k)=true;
        if automaticReference,referenceInliers(k,:)=true;referenceSupport(k)=nr-1;referenceSpread(k)=0;referenceStatus(k)="initial_reference_set";end
        imwrite(sourceImage,fullfile(cfg.output,'first_frame.png'));
    else
        dd=nan(nr,2);vv=false(nr,1);
        for j=2:nr
            o=trackers{j}.update(im);dd(j,:)=o.d;vv(j)=o.valid;ncc(k,j)=o.ncc;err(k,j)=o.error;
            if isfield(o,'support'),support(k,j)=o.support;spread(k,j)=o.spread;reason(k,j)=o.reason;end
        end
        if automaticReference
            [m,ok,rd]=mfm.reference_consensus(dd(2:end,:),vv(2:end),cfg);A=eye(2);
            referenceInliers(k,:)=rd.inliers;referenceSupport(k)=rd.support;referenceSpread(k)=rd.spread;referenceStatus(k)=string(rd.status);
        elseif strcmp(cfg.referenceModel,'local_affine')
            assert(strcmp(cfg.referenceTracker,'flow'),'local_affine requires flow reference tracker');
            ids=find(vv(2:end))+1;predictions=nan(numel(ids),2);maps=nan(2,2,numel(ids));
            centers=cfg.rois(:,1:2)+(cfg.rois(:,3:4)-1)/2;
            for h=1:numel(ids)
                j=ids(h);maps(:,:,h)=trackers{j}.accumulatedA;
                predictions(h,:)=dd(j,:)+(centers(1,:)-centers(j,:))*(maps(:,:,h)'-eye(2));
            end
            ok=~isempty(ids);if ok,m=median(predictions,1);A=median(maps,3);else,m=[NaN NaN];A=nan(2);end
        elseif strcmp(cfg.referenceModel,'none')
            m=[0 0];A=eye(2);ok=true;
        else
            [m,A,ok]=mfm.compensate(dd,vv,cfg.rois,cfg.referenceModel);
        end
        if isProfile
            guide=m;if strcmp(cfg.guideMode,'median'),guide=median(dd(vv,:),1);end
            if ok,lastGuide=guide;end
            o=trackers{1}.update(im,lastGuide);
            centroid(k)=o.centroid-m(1);
            if isfield(o,'scale'),profileScale(k)=o.scale;profileShift(k)=o.refineShift;end
        else,o=trackers{1}.update(im);end
        dd(1,:)=o.d;vv(1)=o.valid;d(k,:,:)=reshape(dd,[1 nr 2]);valid(k,:)=vv;ncc(k,1)=o.ncc;err(k,1)=o.error;macro(k,:)=m;
        if isfield(o,'support'),support(k,1)=o.support;spread(k,1)=o.spread;reason(k,1)=o.reason;end
        geom(k)=ok&&o.valid;
        if geom(k)
            relative(k,:)=o.d-m;
            if isProfile,relative(k,2)=NaN;else,body(k,:)=(A\relative(k,:)')';end
        end
    end
    trackSeconds=trackSeconds+toc(tt);
    if mod(k,250)==0,fprintf('%s: %d frames %.1f seconds\n',cfg.video,k,toc(started));end
end
if transposeInput,d=d(:,:,[2 1]);macro=macro(:,[2 1]);relative=relative(:,[2 1]);body=body(:,[2 1]);end
cfg=originalCfg;
result=struct('time',(0:k-1)'/fps,'displacements',d(1:k,:,:),'valid',valid(1:k,:),...
    'ncc',ncc(1:k,:),'error',err(1:k,:),'macro',macro(1:k,:),'relative',relative(1:k,:),...
    'body',body(1:k,:),'centroidRelative',centroid(1:k),'geometryValid',geom(1:k),...
    'profileScale',profileScale(1:k),'profileRefineShift',profileShift(1:k),...
    'cfg',cfg,'metadataFPS',v.FrameRate,'metadataEstimatedFrames',ceil(v.Duration*v.FrameRate),'framesRead',k,...
    'fps',fps,'readSeconds',readSeconds,'trackSeconds',trackSeconds,'algorithmSeconds',toc(started));
result.spatialSupport=support(1:k,:);result.spatialSpread=spread(1:k,:);result.trackingReason=cellstr(reason(1:k,:));
result.referenceInliers=referenceInliers(1:k,:);result.referenceSupport=referenceSupport(1:k);result.referenceSpread=referenceSpread(1:k);result.referenceStatus=cellstr(referenceStatus(1:k));
if automaticReference,result.referenceConsensusCaveat='Most selected patches must share the target body macromotion. Background camera motion is not object-motion truth; profile guidance freezes at the last valid consensus during reference gaps.';end
result.measurementKind='reference_relative';if strcmp(cfg.referenceModel,'none'),result.measurementKind='total_target_displacement';end
result.orthogonalCoordinateIsGuide=isProfile;
if isProfile
    result.profileSupport=trackers{1}.roi;result.profileScaleEnabled=trackers{1}.cfg.profileScale;
    if transposeInput,result.profileSupport=result.profileSupport([2 1 4 3]);end
end
save(fullfile(cfg.output,'result.mat'),'-struct','result','-v7');
tab=table(result.time,result.displacements(:,1,1),result.displacements(:,1,2),result.macro(:,1),result.macro(:,2),...
    result.relative(:,1),result.relative(:,2),result.centroidRelative,result.geometryValid,...
    'VariableNames',{'time_s','total_x_px','total_y_px','macro_x_px','macro_y_px','relative_x_px','relative_y_px','centroid_relative_x_px','valid'});
for j=1:nr,tab.(sprintf('patch%d_valid',j))=result.valid(:,j);tab.(sprintf('patch%d_error',j))=result.error(:,j);end
if automaticReference,tab.reference_inliers=result.referenceSupport;tab.reference_spread_px=result.referenceSpread;tab.reference_status=string(result.referenceStatus);end
writetable(tab,fullfile(cfg.output,'traces.csv'));fid=fopen(fullfile(cfg.output,'config.json'),'w');fwrite(fid,jsonencode(cfg,'PrettyPrint',true));fclose(fid);
fprintf('Finished %d frames; valid %.3f; %.2f s\n',k,mean(result.geometryValid),result.algorithmSeconds);
end
