function tab=run_motion_order_review(tag)
root=fileparts(mfilename('fullpath'));out=fullfile(root,'outputs',tag);
assert(~isfolder(out),'Choose a fresh tag');mkdir(out);rows=struct([]);
for scenario={'slow','weak','null','fast6','overlap'}
    name=scenario{1};truth=load(fullfile(root,'outputs','round2_20260907_auto_validation_1612','videos',[name '_truth.mat']));
    r=load(fullfile(root,'outputs','guided_review_20260908',[name '_profile'],'result.mat'));
    for order=[2 4]
        for cutoff=[1 3]
            started=tic;s=mfm.separate_motion(r.relative(:,1),r.fps,cutoff,order);elapsed=toc(started);
            % Same evaluation samples across orders and cutoffs, retain gap mask.
            good=false(size(r.time));good(101:end-100)=true;good=good&s.interior;
            e=s.vibration(good)-truth.micro(good,1);rmse=sqrt(mean(e.^2));
            frequency=17.3;if strcmp(name,'overlap'),frequency=6.7;end
            X=[ones(nnz(good),1) sin(2*pi*frequency*r.time(good)) cos(2*pi*frequency*r.time(good))];
            b=X\s.vibration(good);bt=X\truth.micro(good,1);amp=hypot(b(2),b(3));ampTruth=hypot(bt(2),bt(3));
            ratio=NaN;if ampTruth>1e-8,ratio=amp/ampTruth;end
            row=struct('scenario',name,'order',order,'cutoffHz',cutoff,'samples',nnz(good),...
                'rmsePx',rmse,'amplitudeRatio',ratio,'candidateRmsPx',sqrt(mean(s.vibration(good).^2)),...
                'algorithmSeconds',r.algorithmSeconds,'separationSeconds',elapsed);
            rows=[rows;row]; %#ok<AGROW>
            save(fullfile(out,sprintf('%s_order%d_fc%d.mat',name,order,cutoff)),'-struct','s');
        end
    end
end
tab=struct2table(rows);writetable(tab,fullfile(out,'metrics.csv'));disp(tab);
end
