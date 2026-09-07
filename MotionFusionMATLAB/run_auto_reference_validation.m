function metrics=run_auto_reference_validation(tag,scenarios)
% End-to-end analytic-video validation. Truth is used only after measurement.
if nargin<1,tag='auto_reference_validation_v1';end
if nargin<2,scenarios={'slow','fast6','overlap','weak','null','occlusion','ambiguous','axis_y','axis_xy'};end
root=fileparts(mfilename('fullpath'));addpath(root);test_auto_reference();out=fullfile(root,'outputs',tag);
assert(~isfolder(out),'Validation output exists; choose a new tag');mkdir(out);videoRoot=fullfile(out,'videos');mkdir(videoRoot);rows=struct([]);
write_manifest(out,tag,scenarios);
for s=1:numel(scenarios)
    scenario=scenarios{s};video=fullfile(videoRoot,[scenario '.avi']);truth=[];generationError='';
    try
        truth=generate_video(video,scenario);save(fullfile(videoRoot,[scenario '_truth.mat']),'-struct','truth');
        if s==1
            try,verify_filename_invariance(video,truth,out);catch ex
                generationError=sprintf('filename_invariance: %s',ex.message);
                write_text(fullfile(out,'filename_invariance_error.txt'),getReport(ex));
            end
        end
    catch ex
        generationError=ex.message;write_text(fullfile(videoRoot,[scenario '_generation_error.txt']),getReport(ex));
    end
    for method={'manual','automatic'}
        mode=method{1};row=empty_row(scenario,mode);row.error=generationError;
        try
            assert(isstruct(truth)&&~isempty(fieldnames(truth)),'Video generation failed: %s',generationError);
            u=mfm.real_defaults();u.videoPath=video;u.outputRoot=fullfile(out,mode);u.captureFPS=truth.fs;u.maxFrames=truth.frames;
            u.roiMode='manual';u.targetROI=truth.targetROI;u.axis=truth.axis;u.targetMode=truth.targetMode;u.referenceModel='translation';
            u.referenceTracker='anchor';u.showFigures=false;u.exportFigures=false;u.denoise=false;u.autoProfileRows=false;
            if strcmp(mode,'manual'),u.referenceSelection='manual';u.referenceROIs=truth.manualReferenceROI;
            else,u.referenceSelection='automatic';u.referenceROIs=[];u.searchROI=truth.searchROI;u.automaticReferenceCount=8;end
            r=run_real_video(u);row=evaluate_run(r,truth,scenario,mode);row.status="measured";
            contract={};
            if strcmp(mode,'automatic')
                row.selectedReferences=size(r.roiProvenance.referenceROIs,1);
                row.selectedTopGroup=sum((r.roiProvenance.referenceROIs(:,2)+r.roiProvenance.referenceROIs(:,4)/2)<230);
                if row.selectedReferences~=8,contract{end+1}='automatic selector did not provide eight references';end %#ok<AGROW>
                if strcmp(scenario,'ambiguous')&&row.ambiguousRejectedFrames<=100,contract{end+1}='competing reference motion groups were not rejected';end %#ok<AGROW>
                if strcmp(scenario,'occlusion')&&(row.rejectedReferenceFrames<30||row.failureTotalRetention<=.5),contract{end+1}='reference loss did not preserve target total with relative gaps';end %#ok<AGROW>
                if strcmp(scenario,'axis_y')&&(nnz(isfinite(r.relative(:,1)))~=1||nnz(isfinite(r.relative(:,2)))<=1),contract{end+1}='axis=y output contract failed';end %#ok<AGROW>
                if strcmp(scenario,'axis_xy')&&(nnz(all(isfinite(r.relative),2))<=1||r.orthogonalCoordinateIsGuide),contract{end+1}='axis=xy output contract failed';end %#ok<AGROW>
            end
            if ~isempty(contract),row.status="contract_failure";row.contractFailure=string(strjoin(contract,' | '));end
            row.qualityStatus=classify_quality(row,scenario,mode);
        catch ex
            row.status="error";row.error=string(getReport(ex,'basic'));row.qualityStatus="error";
        end
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        metrics=struct2table(rows);writetable(metrics,fullfile(out,'metrics.csv'));
        fprintf('%s %-9s status %-16s coverage %.3f raw-rmse [%.4f %.4f] amp [%.3f %.3f] seconds %.2f\n',...
            scenario,mode,row.status,row.relativeCoverage,row.rawRmseX,row.rawRmseY,row.rawAmplitudeRatioX,row.rawAmplitudeRatioY,row.algorithmSeconds);
    end
end
metrics=struct2table(rows);writetable(metrics,fullfile(out,'metrics.csv'));
save(fullfile(out,'validation_results.mat'),'metrics','scenarios');
fprintf('Automatic-reference video validation complete: %s\n',out);
end

function truth=generate_video(file,scenario)
rng(7301);fs=100;frames=300;t=(0:frames-1)'/fs;axis='x';targetMode='profile';fMicro=17.3;micro=zeros(frames,2);
tx=25*sin(2*pi*.8*t);ty=6*sin(2*pi*.31*t);micro(:,1)=.28*sin(2*pi*fMicro*t);
switch scenario
    case 'slow',tx=35*sin(2*pi*.35*t);
    case 'fast6',tx=50*sin(2*pi*6*t);
    case 'overlap',fMicro=6.7;tx=45*sin(2*pi*fMicro*t);micro(:,1)=.35*sin(2*pi*fMicro*t+.4)-.35*sin(.4);
    case 'weak',micro(:,1)=.02*sin(2*pi*fMicro*t);
    case 'null',micro(:)=0;
    case 'occlusion',tx=20*sin(2*pi*.8*t);
    case 'ambiguous',tx=22*sin(2*pi*1.1*t);
    case 'axis_y',axis='y';tx=8*sin(2*pi*.4*t);ty=30*sin(2*pi*2*t);micro(:,1)=0;micro(:,2)=.3*sin(2*pi*15.2*t);fMicro=15.2;
    case 'axis_xy',axis='xy';targetMode='texture';tx=20*sin(2*pi*1.1*t);ty=15*sin(2*pi*.7*t);micro(:,1)=.25*sin(2*pi*11.1*t);micro(:,2)=.2*sin(2*pi*13.4*t);fMicro=[11.1 13.4];
    otherwise,error('Unknown automatic-reference scenario: %s',scenario);
end
macro=[tx ty];targetROI=[190 45 100 60];refCenters=[85 185;185 185;285 185;385 185;85 275;185 275;285 275;385 275];
manualReferenceROI=[65 165 40 40];searchROI=[30 140 420 170];
[kx,ky,phi,amp]=texture_parameters();vw=VideoWriter(file,'Motion JPEG AVI');vw.FrameRate=fs;vw.Quality=100;open(vw);cleanup=onCleanup(@()close(vw));
for k=1:frames
    im=25+zeros(340,480);hideRefs=strcmp(scenario,'occlusion')&&k>=120&&k<=165;
    if ~hideRefs
        for j=1:size(refCenters,1)
            d=macro(k,:);if strcmp(scenario,'ambiguous')&&j>4,d=-macro(k,:);end
            cx=refCenters(j,1)+d(1);cy=refCenters(j,2)+d(2);xs=max(1,floor(cx-28)):min(480,ceil(cx+28));ys=max(1,floor(cy-28)):min(340,ceil(cy+28));
            [uu,vv]=meshgrid(xs-cx,ys-cy);val=112+zeros(size(uu));for q=1:numel(amp),val=val+amp(q)*cos(2*pi*(kx(q)*uu+ky(q)*vv)+phi(q)+.31*j);end
            patch=im(ys,xs);mask=abs(uu)<=28&abs(vv)<=28;patch(mask)=val(mask);im(ys,xs)=patch;
        end
    end
    center=[240 75]+macro(k,:)+micro(k,:);xs=max(1,floor(center(1)-43)):min(480,ceil(center(1)+43));ys=max(1,floor(center(2)-26)):min(340,ceil(center(2)+26));[uu,vv]=meshgrid(xs-center(1),ys-center(2));patch=im(ys,xs);
    if strcmp(targetMode,'profile')
        mask=abs(vv)<=24&abs(uu)<=42;val=42+178*exp(-(uu/17).^8)+18*cos(.23*uu);patch(mask)=val(mask);
    else
        mask=abs(vv)<=25&abs(uu)<=42;val=115+45*cos(.17*uu+.11*vv)+35*sin(.09*uu-.19*vv)+22*cos(.31*uu-.07*vv);patch(mask)=val(mask);
    end
    im(ys,xs)=patch;
    im=uint8(min(255,max(0,im+.45*randn(size(im)))));writeVideo(vw,repmat(im,1,1,3));
end
clear cleanup
truth=struct('time',t,'macro',macro,'micro',micro,'fs',fs,'frames',frames,'axis',axis,'targetMode',targetMode,...
    'targetROI',targetROI,'manualReferenceROI',manualReferenceROI,'searchROI',searchROI,'frequencyHz',fMicro,'scenario',scenario);
end

function [kx,ky,phi,amp]=texture_parameters()
kx=[.031 .047 -.063 .082 -.026 .071]';ky=[.057 -.038 .074 .029 -.086 -.052]';
phi=[.2 1.1 2.4 -.7 .8 -1.8]';amp=[18 16 13 11 10 9]';
end

function row=evaluate_run(r,truth,scenario,method)
n=min(r.framesRead,truth.frames);measured=r.relative(1:n,:);z=truth.micro(1:n,:);t=truth.time(1:n);good=r.geometryValid(1:n);
rmse=[NaN NaN];ratio=[NaN NaN];validSamples=[0 0];for a=1:2
    ids=good&isfinite(measured(:,a));validSamples(a)=nnz(ids);if validSamples(a)>=2
        rmse(a)=sqrt(mean((measured(ids,a)-z(ids,a)).^2));ratio(a)=amplitude_ratio(measured(ids,a),z(ids,a),t(ids),truth.frequencyHz(min(a,numel(truth.frequencyHz))));
    end
end
axisIds=1;if strcmp(truth.axis,'y'),axisIds=2;elseif strcmp(truth.axis,'xy'),axisIds=1:2;end
failure=~good;retained=false(n,1);total=reshape(r.displacements(1:n,1,:),[n 2]);retained(failure)=r.valid(failure,1)&all(isfinite(total(failure,:)),2)&all(isnan(measured(failure,axisIds)),2);
retention=NaN;if any(failure),retention=mean(retained(failure));end
if strcmp(r.cfg.referenceSelection,'automatic'),refSupport=r.referenceSupport(1:n);refSpread=r.referenceSpread(1:n);else,refSupport=sum(r.valid(1:n,2:end),2);refSpread=nan(n,1);end
ambiguousRejected=sum(strcmp(r.referenceStatus(1:n),'ambiguous_motion_groups'));insufficientReference=sum(strcmp(r.referenceStatus(1:n),'insufficient_valid_references'));
rejectedReference=sum(~ismember(r.referenceStatus(1:n),{'ok','initial_reference_set'}));
row=empty_row(scenario,method);row.axis=truth.axis;row.frames=n;row.relativeCoverage=mean(good);...
    row.targetCoverage=mean(r.valid(1:n,1));row.rmseX=rmse(1);row.rmseY=rmse(2);row.amplitudeRatioX=ratio(1);row.amplitudeRatioY=ratio(2);...
    row.rawRmseX=rmse(1);row.rawRmseY=rmse(2);row.rawAmplitudeRatioX=ratio(1);row.rawAmplitudeRatioY=ratio(2);row.validSamplesX=validSamples(1);row.validSamplesY=validSamples(2);...
    row.rawRmsX=sqrt(mean(measured(:,1).^2,'omitnan'));row.rawRmsY=sqrt(mean(measured(:,2).^2,'omitnan'));...
    row.truthRmsX=sqrt(mean(z(:,1).^2,'omitnan'));row.truthRmsY=sqrt(mean(z(:,2).^2,'omitnan'));
    row.rmseToTruthRmsX=rmse(1)/max(eps,row.truthRmsX);row.rmseToTruthRmsY=rmse(2)/max(eps,row.truthRmsY);...
    row.failureFrames=nnz(failure);row.failureTotalRetention=retention;row.meanReferenceSupport=mean(refSupport);...
    row.meanReferenceSpread=mean(refSpread,'omitnan');row.ambiguousRejectedFrames=ambiguousRejected;row.insufficientReferenceFrames=insufficientReference;row.rejectedReferenceFrames=rejectedReference;...
    row.selectedReferences=size(r.cfg.rois,1)-1;row.algorithmSeconds=r.algorithmSeconds;row.rawUnfiltered=true;
end

function row=empty_row(scenario,method)
row=struct('scenario',scenario,'method',method,'axis','','frames',NaN,'relativeCoverage',NaN,'targetCoverage',NaN,...
    'rmseX',NaN,'rmseY',NaN,'amplitudeRatioX',NaN,'amplitudeRatioY',NaN,'rawRmseX',NaN,'rawRmseY',NaN,'validSamplesX',NaN,'validSamplesY',NaN,'rawRmsX',NaN,'rawRmsY',NaN,...
    'rawAmplitudeRatioX',NaN,'rawAmplitudeRatioY',NaN,'truthRmsX',NaN,'truthRmsY',NaN,'rmseToTruthRmsX',NaN,'rmseToTruthRmsY',NaN,...
    'failureFrames',NaN,'failureTotalRetention',NaN,'meanReferenceSupport',NaN,'meanReferenceSpread',NaN,...
    'ambiguousRejectedFrames',NaN,'insufficientReferenceFrames',NaN,'rejectedReferenceFrames',NaN,'selectedReferences',NaN,'selectedTopGroup',NaN,...
    'algorithmSeconds',NaN,'rawUnfiltered',true,'status',"not_started",'contractFailure',"",'qualityStatus',"not_started",'error',"");
end

function quality=classify_quality(row,scenario,method)
if strcmp(row.status,"error"),quality="error";return;end
if strcmp(scenario,'occlusion')||(strcmp(scenario,'ambiguous')&&strcmp(method,'automatic'))
    quality="rejection_case";return;
end
if strcmp(scenario,'null'),quality="null_reported";return;end
ids=1;if strcmp(row.axis,'y'),ids=2;elseif strcmp(row.axis,'xy'),ids=1:2;end
if any([row.validSamplesX row.validSamplesY](ids)<2),quality="insufficient_samples";return;end
rmse=[row.rawRmseX row.rawRmseY];amp=[row.rawAmplitudeRatioX row.rawAmplitudeRatioY];truthRms=[row.truthRmsX row.truthRmsY];
if strcmp(scenario,'weak'),rmseOK=all([row.rmseToTruthRmsX row.rmseToTruthRmsY](ids)<=.5);ampOK=true;else
    rmseOK=all(rmse(ids)<.06);ampOK=all(isfinite(amp(ids))&amp(ids>=.8)&amp(ids<=1.2);
end
if row.relativeCoverage>=.95&&rmseOK&&ampOK,quality="pass";else,quality="fail";end
end

function write_manifest(out,tag,scenarios)
thresholds=struct('normalCoverageMin',.95,'normalRawRmseMaxPx',.06,'normalAmplitudeRatioMin',.8,'normalAmplitudeRatioMax',1.2,...
    'weakRmseToTruthRmsMax',.5,'nullUsesRawRms',true,'occlusionAndAmbiguous','report rejection and total-displacement retention separately');
manifest=struct('tag',tag,'created',datestr(now,30),'scenarios',{scenarios},'thresholds',thresholds,...
    'interpretation','Engineering acceptance conditions fixed before measurement; not universal accuracy claims. Pixel and amplitude metrics are raw unfiltered outputs.');
write_text(fullfile(out,'manifest.json'),jsonencode(manifest,'PrettyPrint',true));
end

function write_text(path,txt)
fid=fopen(path,'w');assert(fid>=0,'Cannot write %s',path);fwrite(fid,txt,'char');fclose(fid);
end

function ratio=amplitude_ratio(y,z,t,f)
X=[sin(2*pi*f*t) cos(2*pi*f*t) ones(numel(t),1) t];b=X\y;bt=X\z;den=hypot(bt(1),bt(2));ratio=hypot(b(1),b(2))/den;if den<1e-9,ratio=NaN;end
end

function verify_filename_invariance(video,truth,out)
renamed=fullfile(out,'videos','same_bytes_different_name.avi');copyfile(video,renamed);v1=VideoReader(video);a=readFrame(v1);v2=VideoReader(renamed);b=readFrame(v2);
if size(a,3)==3,a=rgb2gray(a);end;if size(b,3)==3,b=rgb2gray(b);end
u=mfm.real_defaults();u.roiMode='manual';u.targetROI=truth.targetROI;u.referenceSelection='automatic';u.referenceModel='translation';u.searchROI=truth.searchROI;
u.videoPath=video;[~,ra,pa]=mfm.resolve_rois(u,a);u.videoPath=renamed;[~,rb,pb]=mfm.resolve_rois(u,b);
assert(isequal(ra,rb)&&isequal(pa.referenceScores,pb.referenceScores),'Renaming identical video bytes changed automatic selection');
end
