function tab=evaluate_laser(tag)
% Laser is only accessible in this evaluator. Scale and lag fit on first half.
% fs=100 for laser remains an acquisition assumption, not verified metadata.
srcRoot=fileparts(mfilename('fullpath'));root=fileparts(srcRoot);names={'motion13','motion27','random27','static13','static27','bridge'};
laserPaths={'E:/sanjiao/0819/2-5mvpp-motion.csv','E:/sanjiao/0819/4-25mvpp-motion.csv',...
    'E:/sanjiao/0819/4-25mvpp-luandong.csv','E:/sanjiao/0819/2-5mvpp-static.csv','E:/sanjiao/0819/4-25mvpp-static.csv','E:/sanjiao/0726/man-qiao.csv'};
rows=struct([]);band=[5 45];
for k=1:numel(names)
    file=fullfile(root,'outputs',tag,names{k},'result.mat');if ~isfile(file),continue;end
    r=load(file);raw=readmatrix(laserPaths{k});laser=raw(:,3);laser(laser<=-900)=NaN;
    % Filtering separate halves avoids cross-boundary leakage from filtfilt.
    n=numel(r.time);split=floor(n/2);guard=50;
    series={r.relative(:,1),r.centroidRelative};methods={'profile_ic','centroid'};
    oldNames={'0819/2-5mvpp-motion','0819/4-25mvpp-motion','0819/4-25mvpp-luandong','0819/2-5mvpp-static','0819/4-25mvpp-static','07-26_single/man-qiao'};
    oldFile=fullfile(root,'..','MPME','outputs',oldNames{k},'real_data_result.mat');
    if isfile(oldFile)
        old=load(oldFile,'xDisplacement','processingTime');oy=nan(n,1);nn=min(n,numel(old.xDisplacement));oy(1:nn)=old.xDisplacement(1:nn);
        series=[series {oy oy}];methods=[methods {'MPME_existing_total_band','MPME_shared_lag_mask'}];
    end
    primaryLag=[];
    for j=1:numel(series)
        y=series{j};yb=nan(n,1);yb(1:split)=mfm.band_segments(y(1:split),r.fps,band);yb(split+1:end)=mfm.band_segments(y(split+1:end),r.fps,band);
        lb=mfm.band_segments(laser,100,band);cal=(1:n)'>guard&(1:n)'<split-guard;test=(1:n)'>split+guard&(1:n)'<=n-guard;
        lag=[];if j==4,lag=primaryLag;yb(~isfinite(primaryBand))=NaN;end
        [stats,z,fit]=align(yb,lb,r.fps,cal,test,lag);
        if j==1,primaryLag=stats.lagFrames;primaryBand=yb;end
        stats.caseName=names{k};stats.method=methods{j};stats.validFraction=mean(isfinite(yb));stats.seconds=r.algorithmSeconds;
        if j>=3,stats.seconds=old.processingTime.algorithmSeconds;end
        stats.peakHz=peak(yb,r.fps);stats.laserHz=peak(lb,100);stats.laserFPSAssumed=100;stats.scaleFitted=true;
        if isempty(rows),rows=stats;else,rows(end+1)=stats;end %#ok<AGROW>
        actualCal=cal&isfinite(yb)&isfinite(z);actualTest=test&isfinite(yb)&isfinite(z);
        data=table(r.time,y,yb,z,fit,actualCal,actualTest,'VariableNames',{'time_s','raw_relative_px','band_px','laser_aligned_mm','fitted_laser_px','calibration','heldout'});
        writetable(data,fullfile(root,'outputs',tag,names{k},[methods{j} '_laser.csv']));
        fprintf('%s %s %s valid %.3f PCC %.4f NRMSE %.3f\n',names{k},methods{j},stats.status,stats.validFraction,stats.pcc,stats.nrmse);
    end
end
tab=struct2table(rows);writetable(tab,fullfile(root,'outputs',tag,'laser_comparison.csv'));
end
function [s,z,fitted]=align(y,laser,fs,cal,test,fixedLag)
n=numel(y);t=(0:n-1)'/fs;lt=(0:numel(laser)-1)'/100;
s=struct('status','insufficient_valid_samples','calibrationSamples',0,'heldoutSamples',0,'lagFrames',NaN,'gainPxPerMM',NaN,'calibrationPCC',NaN,'pcc',NaN,'rmsePx',NaN,'nrmse',NaN);
z=nan(n,1);fitted=z;cal=cal&isfinite(y);test=test&isfinite(y);
if nnz(cal)<80||nnz(test)<80,return;end
if any(~isfinite(laser)),s.status='laser_missing_data';return;end
candidates=-min(250,floor(n/4)):min(600,numel(laser)-floor(n/2));scores=-inf(size(candidates));
for k=1:numel(candidates),scores(k)=score(candidates(k));end
[best,idx]=max(scores);if ~isfinite(best),s.status='insufficient_overlap';return;end
fine=candidates(idx)+(-1:.02:1);scores=arrayfun(@score,fine);[~,idx]=max(scores);lag=fine(idx);
if ~isempty(fixedLag)
    if ~isfinite(fixedLag),s.status='primary_alignment_unavailable';return;end
    lag=fixedLag;
end
z=interp1(lt,laser,t+lag/fs,'spline',NaN);ci=cal&isfinite(z);ti=test&isfinite(z);
beta=[z(ci) ones(nnz(ci),1)]\y(ci);fitted=beta(1)*z+beta(2);e=y(ti)-fitted(ti);
s.status='evaluated';s.calibrationSamples=nnz(ci);s.heldoutSamples=nnz(ti);s.lagFrames=lag;s.gainPxPerMM=beta(1);s.calibrationPCC=abs(corr(y(ci),z(ci)));
s.pcc=corr(y(ti),sign(beta(1))*z(ti));s.rmsePx=sqrt(mean(e.^2));s.nrmse=s.rmsePx/std(y(ti),1);
    function a=score(lag)
        zz=interp1(lt,laser,t+lag/fs,'spline',NaN);ids=cal&isfinite(zz);jt=test&isfinite(zz);a=-Inf;
        if nnz(ids)<.85*nnz(cal)||nnz(jt)<.85*nnz(test),return;end
        a=abs(corr(y(ids),zz(ids)));
    end
end
function hz=peak(x,fs)
e=diff([false;isfinite(x);false]);s=find(e==1);f=find(e==-1)-1;hz=NaN;if isempty(s),return;end
[n,k]=max(f-s+1);if n<32,return;end;x=detrend(x(s(k):f(k)));a=abs(fft(x.*hann(n)));freq=(0:n-1)'*fs/n;a(freq<5|freq>45)=0;[~,j]=max(a);hz=freq(j);
end
