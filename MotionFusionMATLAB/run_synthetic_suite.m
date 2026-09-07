function results=run_synthetic_suite(tag,seeds,scenarios)
% Analytic image generator independent of the registration interpolator.
% All primary metrics use UNFILTERED reference-relative displacement.
if nargin<1,tag='synthetic_v1';end
if nargin<2,seeds=[42 137];end
if nargin<3,scenarios={'slow','fast6','overlap','rotation','random','lighting','occlusion','null','weak'};end
root=fileparts(mfilename('fullpath'));addpath(root);out=fullfile(root,'outputs',tag);assert(~isfolder(out));mkdir(out);rows=struct([]);
for seed=seeds
for sc=1:numel(scenarios)
    name=scenarios{sc};id=sprintf('%s_seed%d',name,seed);video=fullfile(out,[id '.avi']);
    truth=generate(video,name,seed);c=mfm.defaults();c.video=video;c.fps=60;c.rois=truth.rois;c.radius=55;c.targetMode='texture';c.referenceModel='similarity';c.output=fullfile(out,id);
    r=run_measurement(c);save(fullfile(c.output,'truth.mat'),'-struct','truth');
    n=numel(r.time);good=~truth.hidden(1:n)&r.geometryValid;y=r.relative(:,1);z=truth.micro(1:n,1);
    raw=r.displacements(:,1,1);integer=nan(n,1);
    for k=1:n
        dd=round(squeeze(r.displacements(k,:,:)));[m,~,ok]=mfm.compensate(dd,r.valid(k,:),c.rois,c.referenceModel);
        if ok&&r.valid(k,1),integer(k)=dd(1,1)-m(1);end
    end
    signals={y,raw,integer,raw-movmean(raw,45,'omitnan')};methods={'spatial_ic','target_total','integer_spatial','temporal_trend'};
    for j=1:numel(signals)
        yy=signals{j};ids=good&isfinite(yy);tt=r.time(ids);err=yy(ids)-z(ids);err=err-mean(err);
        X=[sin(2*pi*6.7*tt) cos(2*pi*6.7*tt) ones(numel(tt),1) tt];b=X\yy(ids);bt=X\z(ids);amp=hypot(b(1),b(2));expected=hypot(bt(1),bt(2));ratio=amp/expected;
        if expected<1e-6,ratio=NaN;end
        rmse=sqrt(mean(err.^2));maxerr=max(abs(err));occluded=truth.hidden(1:n);falseValid=0;if any(occluded),falseValid=mean(r.valid(occluded,1));end
        coverage=nnz(ids)/nnz(~truth.hidden(1:n));
        normalizedError=rmse/std(z(ids),1);if expected<1e-6,normalizedError=NaN;end
        passed=coverage>=.95&&rmse<.06&&(isnan(ratio)||(abs(ratio-1)<.2&&normalizedError<.3))&&falseValid<.1;
        row=struct('scenario',name,'seed',seed,'method',methods{j},'validFraction',coverage,'rmsePx',rmse,'nrmse',normalizedError,'maximumErrorPx',maxerr,'amplitudeRatio',ratio,'amplitudePx',amp,'falseValidOcclusion',falseValid,'seconds',r.algorithmSeconds,'passed',passed);
        if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
    end
    fprintf('%s spatial RMSE %.5f amplitude %.3f valid %.3f passed %d\n',id,rows(end-3).rmsePx,rows(end-3).amplitudeRatio,rows(end-3).validFraction,rows(end-3).passed);
    results=struct2table(rows);writetable(results,fullfile(out,'metrics.csv'));
end
end
end
function truth=generate(file,name,seed)
rng(seed);n=240;fs=60;t=(0:n-1)'/fs;f=6;if strcmp(name,'slow'),f=.35;elseif strcmp(name,'overlap'),f=6.7;end
tx=55*sin(2*pi*f*t);ty=12*sin(2*pi*.6*t);a=zeros(n,1);scale=ones(n,1);amp=.35;noise=.7;
if strcmp(name,'random'),tx=35*sin(2*pi*(.5*t+.55*t.^2))+20*sin(2*pi*1.8*t);end
if strcmp(name,'rotation'),a=2.5*pi/180*sin(2*pi*.7*t);scale=1+.015*sin(2*pi*.43*t);end
if strcmp(name,'null'),amp=0;end
if strcmp(name,'weak'),amp=.02;noise=3;end
hidden=false(n,1);if strcmp(name,'occlusion'),hidden(96:110)=true;end
centers=[225 105;120 250;375 250];pivot=mean(centers,1);waves=cell(3,1);
for j=1:3,waves{j}=struct('k',.26*rand(18,2)-.13,'phi',2*pi*rand(18,1)-pi,'amp',3+9*rand(18,1));end
vw=VideoWriter(file,'Motion JPEG AVI');vw.FrameRate=fs;vw.Quality=100;open(vw);cleanup=onCleanup(@()close(vw));micro=zeros(n,2);
for i=1:n
    A=scale(i)*[cos(a(i)) -sin(a(i));sin(a(i)) cos(a(i))];pos=(centers-pivot)*A'+pivot+[tx(i) ty(i)];micro(i,:)=(A*[amp*sin(2*pi*6.7*t(i));0])';pos(1,:)=pos(1,:)+micro(i,:);im=22*ones(360,512);
    for j=1:3
        cx=pos(j,1);cy=pos(j,2);xs=max(1,floor(cx-39)):min(512,ceil(cx+39));ys=max(1,floor(cy-39)):min(360,ceil(cy+39));[X,Y]=meshgrid(xs,ys);
        coords=([X(:)-cx Y(:)-cy]/A');w=waves{j};ap=w.amp.*sinc(w.k(:,1)).*sinc(w.k(:,2));val=125+cos(2*pi*coords*w.k'+w.phi')*ap;
        if strcmp(name,'lighting'),val=(.9+.12*sin(2*pi*1.3*t(i)))*val+12*sin(2*pi*.8*t(i));end
        if j==1&&hidden(i),val(:)=22;end
        mask=max(abs(coords),[],2)<35;patch=im(ys,xs);patch(mask)=val(mask);im(ys,xs)=patch;
    end
    im=uint8(im+noise*randn(size(im)));writeVideo(vw,repmat(im,1,1,3));
end
truth=struct('time',t,'micro',micro,'macro',[tx ty],'hidden',hidden,'rois',[centers-24 repmat([48 48],3,1)],'seed',seed,'scenario',name,'rendering','analytic textures, pixel-aperture sinc, MJPEG quality100');
end
