function rows=run_guided_profile_review(tag)
root=fileparts(mfilename('fullpath'));out=fullfile(root,'outputs',tag);
assert(~isfolder(out),'Choose a fresh tag');mkdir(out);rows=struct([]);
source=fullfile(root,'outputs','round2_20260907_auto_validation_1612','videos');
for scenario={'slow','weak','null','fast6','overlap'}
    name=scenario{1};truth=load(fullfile(source,[name '_truth.mat']));
    for mode={'profile','guided_profile'}
        c=mfm.defaults();c.video=fullfile(source,[name '.avi']);c.output=fullfile(out,[name '_' mode{1}]);
        c.rois=truth.targetROI;c.fps=truth.fs;c.maxFrames=truth.frames;
        c.referenceModel='none';c.targetMode=mode{1};c.autoProfileRows=false;c.fastSearch=true;
        r=run_measurement(c);axisId=1;
        x=r.relative(:,axisId);s=mfm.separate_motion(x,r.fps,1);
        good=s.interior&isfinite(truth.micro(:,axisId));
        rmse=NaN;if nnz(good)>10,rmse=sqrt(mean((s.vibration(good)-truth.micro(good,axisId)).^2));end
        row=struct('scenario',name,'mode',mode{1},'coverage',mean(isfinite(x)),...
            'interiorSamples',nnz(good),'candidateRmsePx',rmse,'algorithmSeconds',r.algorithmSeconds);
        rows=[rows;row]; %#ok<AGROW>
        writetable(struct2table(rows),fullfile(out,'metrics.csv'));
        save(fullfile(c.output,'separation.mat'),'-struct','s');
    end
end
end
