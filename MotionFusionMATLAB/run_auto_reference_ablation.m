function metrics=run_auto_reference_ablation(tag,sourceTag,scenarios)
% Reuse analytic AVI/truth files; compare reference affine on/off without overwrite.
if nargin<1,tag='auto_reference_affine_ablation_v1';end
if nargin<2,sourceTag='round_20260907_auto_synthetic';end
if nargin<3,scenarios={'slow','fast6','overlap','weak','null','occlusion','ambiguous','axis_y','axis_xy'};end
root=fileparts(mfilename('fullpath'));source=fullfile(root,'outputs',sourceTag,'videos');assert(isfolder(source),'Source validation videos are missing');
out=fullfile(root,'outputs',tag);assert(~isfolder(out),'Ablation output exists; choose a new tag');mkdir(out);rows=struct([]);write_manifest(out,tag,sourceTag,scenarios);
for s=1:numel(scenarios)
    scenario=scenarios{s};video=fullfile(source,[scenario '.avi']);truth=load(fullfile(source,[scenario '_truth.mat']));assert(isfile(video),'Missing source AVI');
    for affine=[false true]
        variant='translation_only';if affine,variant='affine_reference';end
        row=empty_row(scenario,variant,affine);
        try
            u=mfm.real_defaults();u.videoPath=video;u.outputRoot=fullfile(out,variant);u.captureFPS=truth.fs;u.maxFrames=truth.frames;
            u.roiMode='manual';u.targetROI=truth.targetROI;u.axis=truth.axis;u.targetMode=truth.targetMode;u.referenceModel='translation';
            u.referenceSelection='automatic';u.referenceROIs=[];u.searchROI=truth.searchROI;u.automaticReferenceCount=8;u.automaticReferenceAffine=affine;
            u.referenceTracker='anchor';u.showFigures=false;u.exportFigures=false;u.denoise=false;u.autoProfileRows=false;
            r=run_real_video(u);row=score(r,truth,scenario,variant,affine);row.status="measured";row.qualityStatus=classify_quality(row,scenario);
        catch ex
            row.status="error";row.error=string(getReport(ex,'basic'));row.qualityStatus="error";
        end
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        metrics=struct2table(rows);writetable(metrics,fullfile(out,'metrics.csv'));
        fprintf('%s %-17s status %-10s coverage %.3f raw-rmse [%.4f %.4f] seconds %.2f\n',scenario,variant,row.status,row.relativeCoverage,row.rawRmseX,row.rawRmseY,row.algorithmSeconds);
    end
end
metrics=struct2table(rows);writetable(metrics,fullfile(out,'metrics.csv'));save(fullfile(out,'ablation_results.mat'),'metrics','sourceTag','scenarios');
end

function row=score(r,truth,scenario,variant,affine)
n=min(r.framesRead,truth.frames);y=r.relative(1:n,:);z=truth.micro(1:n,:);t=truth.time(1:n);good=r.geometryValid(1:n);rmse=[NaN NaN];ratio=[NaN NaN];validSamples=[0 0];
for a=1:2
    ids=good&isfinite(y(:,a));validSamples(a)=nnz(ids);if validSamples(a)>=2,rmse(a)=sqrt(mean((y(ids,a)-z(ids,a)).^2));f=truth.frequencyHz(min(a,numel(truth.frequencyHz)));X=[sin(2*pi*f*t(ids)) cos(2*pi*f*t(ids)) ones(nnz(ids),1) t(ids)];b=X\y(ids,a);bt=X\z(ids,a);den=hypot(bt(1),bt(2));if den>=1e-9,ratio(a)=hypot(b(1),b(2))/den;end,end
end
failure=~good;total=reshape(r.displacements(1:n,1,:),[n 2]);axisIds=1;if strcmp(truth.axis,'y'),axisIds=2;elseif strcmp(truth.axis,'xy'),axisIds=1:2;end
retained=r.valid(1:n,1)&all(isfinite(total),2)&all(isnan(y(:,axisIds)),2);retention=NaN;if any(failure),retention=mean(retained(failure));end
row=empty_row(scenario,variant,affine);row.axis=truth.axis;row.frames=n;row.relativeCoverage=mean(good);row.targetCoverage=mean(r.valid(1:n,1));
row.rmseX=rmse(1);row.rmseY=rmse(2);row.amplitudeRatioX=ratio(1);row.amplitudeRatioY=ratio(2);row.rawRmseX=rmse(1);row.rawRmseY=rmse(2);
row.rawAmplitudeRatioX=ratio(1);row.rawAmplitudeRatioY=ratio(2);row.validSamplesX=validSamples(1);row.validSamplesY=validSamples(2);row.rawRmsX=sqrt(mean(y(:,1).^2,'omitnan'));row.rawRmsY=sqrt(mean(y(:,2).^2,'omitnan'));row.truthRmsX=sqrt(mean(z(:,1).^2,'omitnan'));row.truthRmsY=sqrt(mean(z(:,2).^2,'omitnan'));
row.rmseToTruthRmsX=rmse(1)/max(eps,row.truthRmsX);row.rmseToTruthRmsY=rmse(2)/max(eps,row.truthRmsY);
row.failureFrames=nnz(failure);row.failureTotalRetention=retention;row.meanReferenceSupport=mean(r.referenceSupport(1:n));row.meanReferenceSpread=mean(r.referenceSpread(1:n),'omitnan');
row.algorithmSeconds=r.algorithmSeconds;row.selectedReferences=size(r.cfg.rois,1)-1;row.rawUnfiltered=true;
end

function row=empty_row(scenario,variant,affine)
row=struct('scenario',scenario,'variant',variant,'affineReference',affine,'axis','','frames',NaN,'relativeCoverage',NaN,'targetCoverage',NaN,...
    'rmseX',NaN,'rmseY',NaN,'amplitudeRatioX',NaN,'amplitudeRatioY',NaN,'rawRmseX',NaN,'rawRmseY',NaN,'validSamplesX',NaN,'validSamplesY',NaN,'rawRmsX',NaN,'rawRmsY',NaN,...
    'rawAmplitudeRatioX',NaN,'rawAmplitudeRatioY',NaN,'truthRmsX',NaN,'truthRmsY',NaN,'rmseToTruthRmsX',NaN,'rmseToTruthRmsY',NaN,...
    'failureFrames',NaN,'failureTotalRetention',NaN,'meanReferenceSupport',NaN,'meanReferenceSpread',NaN,'algorithmSeconds',NaN,...
    'selectedReferences',NaN,'rawUnfiltered',true,'status',"not_started",'qualityStatus',"not_started",'error',"");
end

function quality=classify_quality(row,scenario)
if strcmp(row.status,"error"),quality="error";return;end
if strcmp(scenario,'occlusion')||strcmp(scenario,'ambiguous'),quality="rejection_case";return;end
if strcmp(scenario,'null'),quality="null_reported";return;end
ids=1;if strcmp(row.axis,'y'),ids=2;elseif strcmp(row.axis,'xy'),ids=1:2;end
if any([row.validSamplesX row.validSamplesY](ids)<2),quality="insufficient_samples";return;end
rmse=[row.rawRmseX row.rawRmseY];amp=[row.rawAmplitudeRatioX row.rawAmplitudeRatioY];
if strcmp(scenario,'weak'),rmseOK=all([row.rmseToTruthRmsX row.rmseToTruthRmsY](ids)<=.5);ampOK=true;else
    rmseOK=all(rmse(ids)<.06);ampOK=all(isfinite(amp(ids))&amp(ids>=.8)&amp(ids<=1.2);
end
if row.relativeCoverage>=.95&&rmseOK&&ampOK,quality="pass";else,quality="fail";end
end

function write_manifest(out,tag,sourceTag,scenarios)
thresholds=struct('normalCoverageMin',.95,'normalRawRmseMaxPx',.06,'normalAmplitudeRatioMin',.8,'normalAmplitudeRatioMax',1.2,...
    'weakRmseToTruthRmsMax',.5,'nullUsesRawRms',true,'occlusionAndAmbiguous','report rejection and total-displacement retention separately');
manifest=struct('tag',tag,'sourceTag',sourceTag,'created',datestr(now,30),'scenarios',{scenarios},'thresholds',thresholds,...
    'interpretation','Engineering acceptance conditions fixed before measurement; metrics are raw unfiltered outputs.');
fid=fopen(fullfile(out,'manifest.json'),'w');assert(fid>=0,'Cannot write ablation manifest');fwrite(fid,jsonencode(manifest,'PrettyPrint',true),'char');fclose(fid);
end
