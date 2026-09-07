function rows=compare_laser_v2(resultDirectory,laserPath,laserFPS,column)
% Evaluation AFTER immutable video output. Nothing is returned to tracking.
% One training-only lag, sign, gain for BOTH broad and cleaned predictions.
if nargin<3,laserFPS=100;end;if nargin<4,column=3;end
r=load(fullfile(resultDirectory,'result.mat'));a=readmatrix(laserPath);laser=a(:,column);laser(laser<=-900)=NaN;
assert(all(isfinite(laser)),'Laser has missing values: no silent interpolation');
out=fullfile(resultDirectory,'evaluation');if ~isfolder(out),mkdir(out);end
keys=fieldnames(r.signals);rows=struct([]);
for j=1:numel(keys)
    key=keys{j};s=r.signals.(key);lb=mfm.band_segments(laser,laserFPS,s.bandHz);
    n=numel(r.time);ii=(1:n)';cal=ii>50&ii<floor(n/2)-50&isfinite(s.broad);test=ii>floor(n/2)+50&ii<=n-50;
    tt=(0:numel(lb)-1)'/laserFPS;best=-Inf;lag=NaN;
    if nnz(cal)<80
        for missingMethod={'broad','clean_modal'}
            row=struct('axis',key,'method',missingMethod{1},'samples',0,'coverage',mean(isfinite(s.broad)),'pcc',NaN,'rmsePx',NaN,'nrmseToLaser',NaN,'lagFrames',NaN,'fittedPxPerMM',NaN,'laserFPS',laserFPS,'laserColumn',column,'status','insufficient_training_observations');
            if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        end
        continue;
    end
    candidates=-min(250,floor(n/4)):min(600,numel(lb)*r.fps/laserFPS-n/2);
    for q=candidates,score=fitScore(q);if score>best,best=score;lag=q;end;end
    coarse=lag;for q=coarse+(-1:.02:1),score=fitScore(q);if score>best,best=score;lag=q;end;end
    z=interp1(tt,lb,r.time+lag/r.fps,'spline',NaN);ci=cal&isfinite(z);beta=[z(ci) ones(nnz(ci),1)]\s.broad(ci);fitted=beta(1)*z+beta(2);
    common=test&isfinite(z)&isfinite(s.broad)&isfinite(s.clean);signals={s.broad,s.clean};labels={'broad','clean_modal'};
    for k=1:2
        y=signals{k};e=y(common)-fitted(common);row=struct('axis',key,'method',labels{k},'samples',nnz(common),'coverage',mean(isfinite(y)),'pcc',NaN,'rmsePx',NaN,'nrmseToLaser',NaN,'lagFrames',lag,'fittedPxPerMM',beta(1),'laserFPS',laserFPS,'laserColumn',column,'status','insufficient_heldout_observations');
        if nnz(common)>=80,row.pcc=corr(y(common),sign(beta(1))*z(common));row.rmsePx=sqrt(mean(e.^2));row.nrmseToLaser=row.rmsePx/std(fitted(common),1);row.status='evaluated';end
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
    end
    writetable(table(r.time,s.broad,s.clean,fitted,ci,common,'VariableNames',{'time_s','broad_px','clean_px','training_fitted_laser_px','calibration','common_test'}),fullfile(out,['comparison_' key '.csv']));
end
if ~isempty(rows),writetable(struct2table(rows),fullfile(out,'metrics.csv'));disp(struct2table(rows));end
    function score=fitScore(q)
        zz=interp1(tt,lb,r.time+q/r.fps,'spline',NaN);ok=cal&isfinite(zz);score=-Inf;
        targetTest=test&isfinite(s.broad)&isfinite(s.clean);
        if nnz(ok)<.85*nnz(cal)||nnz(targetTest&isfinite(zz))<.85*nnz(targetTest),return;end
        score=abs(corr(s.broad(ok),zz(ok)));
    end
end
