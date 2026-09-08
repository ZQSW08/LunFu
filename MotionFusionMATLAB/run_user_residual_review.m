function tab=run_user_residual_review(tag,maxFrames)
if nargin<2,maxFrames=500;end
root=fileparts(mfilename('fullpath'));out=fullfile(root,'outputs',tag);
assert(~isfolder(out),'Choose a new tag');mkdir(out);
source=fullfile(root,'outputs','1','1','1','man-qiao-2-profile-wuzhai-wudaitong','result.mat');
old=load(source);rows=struct([]);
for model={'none','translation','similarity'}
    name=model{1};c=old.cfg;c.referenceModel=name;c.targetMode='profile';c.maxFrames=maxFrames;
    c.output=fullfile(out,name);c.rois=old.cfg.rois;
    if strcmp(name,'none'),c.rois=c.rois(1,:);elseif strcmp(name,'translation'),c.rois=c.rois(1:2,:);end
    r=run_measurement(c);r.signals.x=mfm.clean_signal(r.relative(:,1),r.fps,[],false);
    for cutoff=[1 3 6]
        started=tic;s=mfm.separate_motion(r.relative(:,1),r.fps,cutoff,4);seconds=toc(started);
        x=r.relative(:,1);v=s.vibration;v(~s.interior)=NaN;
        raw=x;raw(~s.interior)=NaN;a=mfm.spectrum(raw,r.fps);b=mfm.spectrum(v,r.fps);
        lowBefore=sum(a.amplitude(a.frequency<cutoff).^2);lowAfter=sum(b.amplitude(b.frequency<cutoff).^2);
        ratio=NaN;if lowBefore>0,ratio=lowAfter/lowBefore;end
        row=struct('model',name,'cutoffHz',cutoff,'frames',r.framesRead,...
            'rawCoverage',mean(isfinite(x)),'candidateCoverage',mean(isfinite(v)),...
            'lowBandSquaredAmplitudeRatio',ratio,'algorithmSeconds',r.algorithmSeconds,'separationSeconds',seconds);
        rows=[rows;row]; %#ok<AGROW>
        folder=fullfile(c.output,sprintf('cutoff_%g',cutoff));mkdir(folder);
        writetable(table(r.time,x,s.trend,v,s.interior,...
            'VariableNames',{'time_s','raw_px','trend_px','candidate_px','interior'}),fullfile(folder,'comparison.csv'));
        % Export already measured evidence: no additional tracking/video pass.
        rr=r;rr.cfg.output=folder;rr.motionSeparation.x=s;
        reader=VideoReader(c.video);im=readFrame(reader);if size(im,3)==3,im=rgb2gray(im);end
        export_real_outputs(rr,im,false,true);
    end
    writetable(struct2table(rows),fullfile(out,'metrics.csv'));
end
tab=struct2table(rows);disp(tab);
end
