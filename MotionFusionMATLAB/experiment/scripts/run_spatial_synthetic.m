function run_spatial_synthetic(tag,targetMode)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
% Predeclared independent analytic strip benchmark, without waveform filters.
% Truth is used ONLY after run_measurement returns.
if nargin<2,targetMode='consensus';end
out=fullfile(root,'outputs',tag);assert(~isfolder(out));mkdir(out);
cases={'slow','fast6','overlap','lighting_shape','occlusion','null','weak'};
rows=struct([]);rng(91673);fs=100;N=300;t=(0:N-1)'/fs;
centers=[260 100;135 270;400 270];rois=[224 60 73 81;105 240 61 61;370 240 61 61];
for cidx=1:numel(cases)
    name=cases{cidx};f=6;if strcmp(name,'slow'),f=.35;end
    macro=[50*sin(2*pi*f*t),10*sin(2*pi*.7*t)];
    if strcmp(name,'overlap'),macro(:,1)=50*sin(2*pi*7.31*t);end
    amp=.25;if strcmp(name,'null'),amp=0;elseif strcmp(name,'weak'),amp=.02;end
    micro=amp*sin(2*pi*7.31*t)+.4*amp*sin(2*pi*19.27*t);
    hidden=false(N,1);if strcmp(name,'occlusion'),hidden(115:135)=true;end
    path=fullfile(out,[name '.avi']);vw=VideoWriter(path,'Motion JPEG AVI');vw.FrameRate=fs;vw.Quality=100;open(vw);
    for k=1:N
        im=18*ones(360,550);
        for j=1:3
            center=centers(j,:)+macro(k,:);if j==1,center(1)=center(1)+micro(k);end
            xs=max(1,floor(center(1)-45)):min(550,ceil(center(1)+45));
            ys=max(1,floor(center(2)-50)):min(360,ceil(center(2)+50));
            [X,Y]=meshgrid(xs-center(1),ys-center(2));
            if j==1
                width=3;
                gain=1;
                if strcmp(name,'lighting_shape'),width=3+.8*(k/N);gain=.8+.15*sin(2*pi*.9*t(k));end
                % Pixel-integrated Gaussian via erf, independent of matcher spline.
                val=18+gain*190*width*sqrt(pi/2)*(erf((X+.5)/(sqrt(2)*width))-erf((X-.5)/(sqrt(2)*width)));
                val=val.*(1+.05*sin(.18*Y));
                if hidden(k),val(:)=18;end
            else
                val=100+24*cos(.27*X+.12*Y+j)+30*sin(.11*X-.32*Y)+18*cos(.43*X+.38*Y);
            end
            im(ys,xs)=val;
        end
        im=uint8(im+1.1*randn(size(im)));writeVideo(vw,repmat(im,1,1,3));
    end
    close(vw);save(fullfile(out,[name '_truth.mat']),'micro','macro','hidden','t','rois');
    for variant={'baseline','candidate'}
        cfg=mfm.defaults();cfg.video=path;cfg.rois=rois;cfg.fps=fs;cfg.radius=55;cfg.maxSamples=6500;
        cfg.referenceModel='translation';cfg.fastSearch=true;cfg.autoProfileRows=true;
        cfg.targetMode='profile';cfg.referenceTracker='anchor';
        if strcmp(variant{1},'candidate'),cfg.targetMode=targetMode;cfg.referenceTracker='flow';end
        cfg.output=fullfile(out,[name '_' variant{1}]);r=run_measurement(cfg);
        y=r.relative(:,1);ok=isfinite(y)&~hidden;
        err=y(ok)-micro(ok);bias=mean(err);rmse=sqrt(mean(err.^2));
        B=[sin(2*pi*7.31*t(ok)) cos(2*pi*7.31*t(ok)) sin(2*pi*19.27*t(ok)) cos(2*pi*19.27*t(ok)) ones(nnz(ok),1)];
        b=B\y(ok);a1=hypot(b(1),b(2));a2=hypot(b(3),b(4));
        ratio1=a1/amp;ratio2=a2/(.4*amp);if amp==0,ratio1=NaN;ratio2=NaN;end
        falseValid=0;if any(hidden),falseValid=mean(r.valid(hidden,1));end
        row=struct('scenario',name,'variant',variant{1},'coverage',nnz(ok)/nnz(~hidden),'rmsePx',rmse,...
            'biasPx',bias,'amplitudeRatio1',ratio1,'amplitudeRatio2',ratio2,'falseValidOcclusion',falseValid,...
            'seconds',r.algorithmSeconds,'passed',nnz(ok)/nnz(~hidden)>=.95&&rmse<.06&&...
            (amp==0||abs(ratio1-1)<.2&&abs(ratio2-1)<.2)&&falseValid<.1);
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
        writetable(struct2table(rows),fullfile(out,'metrics.csv'));disp(row);
    end
end
end



