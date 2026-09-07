function run_reproduction()
% RUN_REPRODUCTION 运行 MP-G2LPT V1 的可重复合成验证。
% 本实验使用带真值的自然纹理代理视频，完成报告第 53 节的五组对照。
% 真实视频入口请运行 run_real_video.m；本文件不调用其他论文的后端方法。

close all; clc;
scriptPath=mfilename('fullpath'); projectRoot=fileparts(fileparts(scriptPath));
cfg=default_config(projectRoot); setup_project(cfg);
cfg.video.maxFrames=60; cfg.method.localSearchRadiusPx=4; cfg.output.writeTrackingVideo=true;
outputDir=fullfile(projectRoot,'outputs','reproduction_v1');
if isfolder(outputDir), rmdir(outputDir,'s'); end
mkdir(outputDir);

[frames,trueCenters,roi]=make_synthetic_sequence(cfg);
templateState=initialize_phase_tracker(frames{1},roi,cfg);
methodNames={'intensity_ncc','scalar_phase_ncc','circular_single','circular_multi','poc_local_multi'};
displayNames={'Intensity NCC','Scalar phase NCC','Single-scale circular','Multi-scale circular','POC + local multi-scale'};
allResults=repmat(empty_result(displayNames{1},numel(frames)),1,numel(methodNames));
for m=1:numel(methodNames)
    allResults(m)=empty_result(displayNames{m},numel(frames));
    state=initialize_phase_tracker(frames{1},roi,cfg);
    allResults(m)=put_initial(allResults(m),state.anchor.center);
    for k=2:numel(frames)
        pyramid=build_complex_gabor_pyramid(frames{k},cfg);
        [state,out]=track_one_frame(state,frames{k},cfg,methodNames{m},pyramid);
        allResults(m)=put_result(allResults(m),k,out);
    end
end
save_v1_outputs(outputDir,frames{1},templateState.anchor,...
    allResults,cfg,30,frames,trueCenters);

primary=allResults(end); valid=primary.valid;
if any(valid)
    centerError=sqrt(sum((primary.center(valid,:)-trueCenters(valid,:)).^2,2));
    fprintf('MP-G2LPT V1 synthetic check: median center error = %.3f px, valid rate = %.1f%%\n',...
        median(centerError),100*mean(valid));
else
    fprintf('MP-G2LPT V1 synthetic check: no valid track samples.\n');
end
fprintf('Outputs: %s\n',outputDir);
end

function [frames,trueCenters,roi]=make_synthetic_sequence(cfg)
rng(7,'twister'); H=260; W=420; h=72; w=92; x0=150; y0=82; N=cfg.video.maxFrames;
background=make_texture(H,W); target=make_texture(h,w);
% 加入弱方向纹理与局部结构，避免把合成样例退化成单一正弦条纹。
[xx,yy]=meshgrid(1:w,1:h); target=target+0.06*sin(xx/3.7)+0.04*cos((xx+yy)/8.1); target=normalize_image(target);
frames=cell(N,1); trueCenters=zeros(N,2);
for k=1:N
    tau=(k-1)/(N-1); dx=72*sin(2*pi*0.65*tau)+0.40*sin(2*pi*4*tau); dy=18*sin(2*pi*0.35*tau);
    realTopLeft=[x0+dx,y0+dy]; integerTopLeft=round(realTopLeft); fraction=realTopLeft-integerTopLeft;
    shifted=translate_patch(target,fraction); frame=background;
    x=integerTopLeft(1); y=integerTopLeft(2); frame(y:y+h-1,x:x+w-1)=shifted;
    frames{k}=uint8(255*normalize_image(frame)); trueCenters(k,:)=[realTopLeft(1)+(w-1)/2,realTopLeft(2)+(h-1)/2];
end
roi=[x0 y0 w h];
end

function img=make_texture(h,w)
raw=randn(h,w); smooth=conv2(raw,ones(9,9)/81,'same'); fine=conv2(randn(h,w),ones(3,3)/9,'same');
img=normalize_image(0.6*smooth+0.25*fine+0.15*rand(h,w));
end
function img=translate_patch(patch,fraction)
[h,w]=size(patch); img=zeros(h,w);
for row=1:h
    for col=1:w
        sourceX=col-fraction(1); sourceY=row-fraction(2);
        x0=floor(sourceX); y0=floor(sourceY); x1=x0+1; y1=y0+1;
        ax=sourceX-x0; ay=sourceY-y0;
        x0=min(max(x0,1),w); x1=min(max(x1,1),w); y0=min(max(y0,1),h); y1=min(max(y1,1),h);
        img(row,col)=(1-ay)*((1-ax)*patch(y0,x0)+ax*patch(y0,x1))+...
            ay*((1-ax)*patch(y1,x0)+ax*patch(y1,x1));
    end
end
img=normalize_image(img);
end
function img=normalize_image(img)
img=double(img); img=img-min(img(:)); img=img/max(max(img(:)),eps);
end
function r=empty_result(name,n)
r=struct('name',name,'center',nan(n,2),'integerCenter',nan(n,2),'subpixel',nan(n,2),...
    'quality',nan(n,1),'phaseScore',nan(n,1),'peakRatio',nan(n,1),...
    'crossScaleAgreement',nan(n,1),'subpixelResidualRms',nan(n,1),'valid',false(n,1));
end
function r=put_initial(r,center)
r.center(1,:)=center; r.integerCenter(1,:)=center; r.subpixel(1,:)=[0 0]; r.quality(1)=1; r.phaseScore(1)=1; r.peakRatio(1)=1; r.crossScaleAgreement(1)=1; r.subpixelResidualRms(1)=0; r.valid(1)=true;
end
function r=put_result(r,k,out)
r.center(k,:)=out.center; r.integerCenter(k,:)=out.integerCenter; r.subpixel(k,:)=out.subpixel; r.quality(k)=out.quality; r.phaseScore(k)=out.phaseScore; r.peakRatio(k)=out.peakRatio; r.crossScaleAgreement(k)=out.crossScaleAgreement; r.subpixelResidualRms(k)=out.subpixelResidualRms; r.valid(k)=out.valid;
end
