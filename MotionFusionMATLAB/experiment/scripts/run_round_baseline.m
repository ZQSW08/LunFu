function run_round_baseline(tag)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
% Replay archived geometry/settings with the retained profile/anchor path.
% Archived signals and external sensors are not inputs to measurement.
if nargin<1,tag=['baseline_20260907_' datestr(now,'HHMMSS')];end
out=fullfile(root,'outputs',tag);assert(~isfolder(out));mkdir(out);
names={'2-5mvpp-motion','2-5mvpp-static','4-25mvpp-luandong',...
    '4-25mvpp-motion','4-25mvpp-static','man-qiao','kuai-qiao','3-25mvpp-motion'};
rows=struct([]);
for j=1:numel(names)
    group='real_v3';if j>6,group='manual_v4';end
    source=fullfile(root,'outputs',group,names{j},'result.mat');
    s=load(source,'cfg');c=s.cfg;c.output=fullfile(out,names{j});
    c.targetMode='profile';c.referenceTracker='anchor';c.maxFrames=Inf;
    ticRun=tic;
    try
        r=run_measurement(c);
        r.signals.x=mfm.clean_signal(r.relative(:,1),r.fps,[2 45],true);
        save(fullfile(c.output,'result.mat'),'-struct','r','-v7');
        export_real_outputs(r,imread(fullfile(c.output,'first_frame.png')),false,true);
        old=load(source,'relative');a=old.relative(:,1);b=r.relative(:,1);
        sameLength=numel(a)==numel(b);delta=NaN;maskEqual=false;
        if sameLength
            maskEqual=isequal(isfinite(a),isfinite(b));ok=isfinite(a)&isfinite(b);
            if any(ok),delta=max(abs(a(ok)-b(ok)));end
        end
        row=struct('video',names{j},'frames',r.framesRead,'targetCoverage',mean(r.valid(:,1)),...
            'relativeCoverage',mean(r.geometryValid),'seconds',r.algorithmSeconds,...
            'archivedMaskEqual',maskEqual,'archivedMaxDifferencePx',delta,'status','measured');
    catch ex
        row=struct('video',names{j},'frames',0,'targetCoverage',NaN,'relativeCoverage',NaN,...
            'seconds',toc(ticRun),'archivedMaskEqual',false,'archivedMaxDifferencePx',NaN,'status',ex.message);
        fprintf('%s: %s\n',names{j},getReport(ex));
    end
    if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
    writetable(struct2table(rows),fullfile(out,'summary.csv'));disp(row);
end
end



