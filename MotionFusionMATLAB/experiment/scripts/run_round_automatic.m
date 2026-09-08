function rows=run_round_automatic(tag,maxFrames)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
%RUN_ROUND_AUTOMATIC Re-run eight videos with one fixed automatic-reference setup.
% The archived result is used only for cfg.video and cfg.rois(1,:). Existing
% reference ROIs and all other archived settings are deliberately ignored.
% Measurement is delegated to the public run_real_video entry point.
if nargin<1||isempty(tag),tag=['automatic_round_20260907_' datestr(now,'HHMMSS')];end
if nargin<2||isempty(maxFrames),maxFrames=Inf;end
assert(ischar(tag)||isstring(tag),'tag must be text');
assert(isscalar(maxFrames)&&(isinf(maxFrames)||isfinite(maxFrames)&&maxFrames>=1),...
    'maxFrames must be Inf or a positive scalar');
outRoot=fullfile(root,'outputs',char(tag));
assert(~isfolder(outRoot),'Output tag already exists; choose a new tag');mkdir(outRoot);
names={'2-5mvpp-motion','2-5mvpp-static','4-25mvpp-luandong',...
    '4-25mvpp-motion','4-25mvpp-static','man-qiao','kuai-qiao','3-25mvpp-motion'};
rows=struct([]);
for j=1:numel(names)
    name=names{j};group='real_v3';if j>6,group='manual_v4';end
    source=fullfile(root,'outputs',group,name,'result.mat');
    video='';targetROI=[];u=struct();
    row=emptyRow(name,source);started=tic;
    try
        assert(isfile(source),'Archived result missing: %s',source);
        s=load(source,'cfg');
        % Only these two archived fields enter the new run.
        video=s.cfg.video;targetROI=s.cfg.rois(1,:);
        u=mfm.real_defaults();
        u.videoPath=video;u.outputRoot=outRoot;u.captureFPS=100;u.maxFrames=maxFrames;u.axis='x';
        u.roiMode='manual';u.targetROI=targetROI;u.referenceROIs=[];
        u.referenceSelection='automatic';u.referenceModel='translation';u.referenceTracker='anchor';
        u.searchROI=[];u.targetMode='profile';u.autoProfileRows=true;u.maxSamples=6500;
        u.automaticReferenceCount=8;
        u.analysisBandHz=[2 45];u.denoise=true;u.showFigures=false;u.exportFigures=true;
        r=run_real_video(u);
        row.video=video;row.targetROI=mat2str(targetROI);row.candidateCount=getField(r.roiProvenance,'referenceCandidateCount',NaN);
        row.selectedCount=size(r.cfg.rois,1)-1;row.targetCoverage=mean(r.valid(:,1));
        ok=isfinite(r.relative(:,1));row.relativeCoverage=mean(ok);
        row.lastHalfCoverage=mean(ok(floor(numel(ok)/2)+1:end));
        row.seconds=r.algorithmSeconds;row.totalSeconds=toc(started);
        row.status='measured';row.error='';
    catch ex
        row.seconds=toc(started);row.totalSeconds=row.seconds;row.status=ex.identifier;
        row.error=ex.message;
        % Resolve first-frame candidate count for the expected insufficient-
        % candidate case, without changing the run or selecting a fallback.
        try
            if ~isempty(video)&&~isempty(targetROI)&&isstruct(u)
                [row.candidateCount,row.selectedCount]=candidateCount(video,targetROI,u);
            end
        catch
            % Keep NaN when the video or first frame cannot be inspected.
        end
        folder=fullfile(outRoot,name);if ~isfolder(folder),mkdir(folder);end
        fid=fopen(fullfile(folder,'automatic_error.txt'),'w');
        if fid>=0,fwrite(fid,getReport(ex));fclose(fid);end
    end
    if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
    writetable(struct2table(rows),fullfile(outRoot,'summary.csv'));
end
end

function row=emptyRow(name,source)
row=struct('video',name,'sourceResult',source,'targetROI','','candidateCount',NaN,...
    'selectedCount',NaN,'targetCoverage',NaN,'relativeCoverage',NaN,'lastHalfCoverage',NaN,...
    'seconds',NaN,'totalSeconds',NaN,'status','not_started','error','');
end

function value=getField(s,name,default)
if isstruct(s)&&isfield(s,name),value=s.(name);else,value=default;end
end

function [candidateCount,selectedCount]=candidateCount(video,targetROI,u)
candidateCount=NaN;selectedCount=NaN;v=VideoReader(video);im=readFrame(v);if size(im,3)==3,im=rgb2gray(im);end
c=mfm.defaults();fields={'automaticReferenceCount','automaticPatchSize','automaticMinReferences',...
    'automaticMinInlierRatio','automaticConsensusTolerance','automaticMaxSpread','automaticAmbiguityRatio'};
for k=1:numel(fields),c.(fields{k})=u.(fields{k});end
[refs,info]=mfm.select_reference_patches(im,targetROI,[],c);
candidateCount=info.candidateCount;selectedCount=size(refs,1);
end



