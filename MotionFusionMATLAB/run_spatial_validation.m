function run_spatial_validation(tag,variant)
% All algorithms receive identical geometry. Names are dataset identifiers
% only; no filename-to-frequency/algorithm lookup exists in the estimator.
root=fileparts(mfilename('fullpath'));addpath(root);
names={'2-5mvpp-motion','2-5mvpp-static','4-25mvpp-luandong','4-25mvpp-motion',...
       '4-25mvpp-static','man-qiao','kuai-qiao','3-25mvpp-motion'};
out=fullfile(root,'outputs',tag);if ~isfolder(out),mkdir(out);else,assert(isfile(fullfile(out,'manifest_before_run.json')),'Unmanaged output');end
rows=struct([]);manifest=struct([]);
for j=1:numel(names)
    group='real_v3';if j>=7,group='manual_v4';end
    s=load(fullfile(root,'outputs',group,names{j},'result.mat'),'cfg');
    c=mfm.defaults();c.video=s.cfg.video;c.rois=s.cfg.rois;c.fps=100;
    c.axis='x';c.guideMode='geometry';c.maxSamples=6500;c.autoProfileRows=true;c.fastSearch=true;
    c.referenceModel='translation';if size(c.rois,1)>2,c.referenceModel='similarity';end
    c.output=fullfile(out,names{j});
    c.targetMode='profile';c.referenceTracker='anchor';
    if strcmp(variant,'candidate'),c.targetMode='direct';c.referenceTracker='flow';end
    manifest(j).video=c.video;manifest(j).config=c; %#ok<AGROW>
end
fid=fopen(fullfile(out,'manifest_before_run.json'),'w');
fwrite(fid,jsonencode(manifest,'PrettyPrint',true));fclose(fid);
for j=1:numel(names)
    c=manifest(j).config;errText='';
    try
        if isfile(fullfile(c.output,'result.mat')),r=load(fullfile(c.output,'result.mat'));else,r=run_measurement(c);end
        r.signals.x=mfm.clean_signal(r.relative(:,1),r.fps,[],false);
        save(fullfile(c.output,'result.mat'),'-struct','r','-v7');
        first=imread(fullfile(c.output,'first_frame.png'));
        export_real_outputs(r,first,false,true);
        y=r.relative(:,1);ok=isfinite(y);N=numel(y);
        row=struct('video',names{j},'variant',variant,'frames',N,'targetCoverage',mean(r.valid(:,1)),...
            'referenceCoverage',mean(all(r.valid(:,2:end),2)),'relativeCoverage',mean(ok),...
            'lastHalfCoverage',mean(ok(floor(N/2)+1:end)),'algorithmSeconds',r.algorithmSeconds,...
            'trackSeconds',r.trackSeconds,'readSeconds',r.readSeconds,...
            'rawStdPx',std(y(ok),1),'accuracyValidated',false,'status','measured');
    catch ex
        errText=getReport(ex);fprintf('%s\n',errText);
        row=struct('video',names{j},'variant',variant,'frames',0,'targetCoverage',NaN,...
            'referenceCoverage',NaN,'relativeCoverage',NaN,'lastHalfCoverage',NaN,...
            'algorithmSeconds',NaN,'trackSeconds',NaN,'readSeconds',NaN,'rawStdPx',NaN,...
            'accuracyValidated',false,'status',ex.identifier);
        fid=fopen(fullfile(out,[names{j} '_error.txt']),'w');fwrite(fid,errText);fclose(fid);
    end
    if isempty(rows),rows=row;else,rows(end+1)=row;end;writetable(struct2table(rows),fullfile(out,'summary.csv')); %#ok<AGROW>
end
end
