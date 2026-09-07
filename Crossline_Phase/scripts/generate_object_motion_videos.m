function manifest = generate_object_motion_videos(outputRoot, userCfg)
%GENERATE_OBJECT_MOTION_VIDEOS 生成带具体机械物体外观的测试视频。
% 物体由圆盘轮毂、锥形机械臂、边缘高光和螺栓组成；白色 crossline
% 绘制在轮毂表面，因此会随物体发生水平大运动、模糊、光照变化和旋转。
% 所有视频均为 100 fps、10 s、1000 帧，并保存逐帧真值。

if nargin<1 || isempty(outputRoot)
    projectRoot=fileparts(fileparts(mfilename('fullpath')));
    outputRoot=fullfile(projectRoot,'outputs','object_motion_videos');
end
if nargin<2 || isempty(userCfg), userCfg=struct(); end
cfg=default_cfg(outputRoot); cfg=merge_cfg(cfg,userCfg);
if ~isfolder(cfg.outputRoot), mkdir(cfg.outputRoot); end
rng(cfg.randomSeed,'twister'); scenes=scene_table();
manifest=repmat(struct('name','','videoPath','','truthPath','','previewPath','', ...
    'fps',cfg.fps,'duration_s',cfg.numFrames/cfg.fps,'numFrames',cfg.numFrames, ...
    'largeFrequenciesHz',[],'microFrequencyHz',cfg.microFrequencyHz, ...
    'initialCenter',[],'recommendedRoi',[],'condition',''),1,numel(scenes));

for s=1:numel(scenes)
    scene=scenes(s); videoPath=fullfile(cfg.outputRoot,[scene.name '.avi']);
    truthPath=fullfile(cfg.outputRoot,[scene.name '_truth.mat']);
    previewPath=fullfile(cfg.outputRoot,[scene.name '_first_frame.png']);
    writer=VideoWriter(videoPath,'Motion JPEG AVI'); writer.FrameRate=cfg.fps; writer.Quality=cfg.quality; open(writer);
    centers=zeros(cfg.numFrames,2); largeCenters=zeros(cfg.numFrames,2); microCenters=zeros(cfg.numFrames,2); angles=zeros(cfg.numFrames,1); firstFrame=[];
    for k=1:cfg.numFrames
        t=(k-1)/cfg.fps; [center,largeCenter,microCenter,angleDeg]=motion_truth(scene,t,cfg);
        frame=render_conditioned(scene,t,cfg,k); writeVideo(writer,repmat(frame,[1 1 3]));
        if k==1, firstFrame=frame; end
        centers(k,:)=center; largeCenters(k,:)=largeCenter; microCenters(k,:)=microCenter; angles(k)=angleDeg;
    end
    close(writer); imwrite(firstFrame,previewPath); time=(0:cfg.numFrames-1)'/cfg.fps; %#ok<NASGU>
    initialCenter=centers(1,:); recommendedRoi=make_roi(initialCenter,cfg); sceneMeta=scene; %#ok<NASGU>
    save(truthPath,'time','centers','largeCenters','microCenters','initialCenter','recommendedRoi','sceneMeta','cfg');
    writetable(table((1:cfg.numFrames)',time,centers(:,1),centers(:,2),largeCenters(:,1),largeCenters(:,2), ...
        microCenters(:,1),microCenters(:,2),angles,'VariableNames',{'frame','time_s','truth_x','truth_y','large_x','large_y','micro_x','micro_y','angle_deg'}), ...
        fullfile(cfg.outputRoot,[scene.name '_truth.csv']));
    manifest(s).name=scene.name; manifest(s).videoPath=videoPath; manifest(s).truthPath=truthPath; manifest(s).previewPath=previewPath;
    manifest(s).largeFrequenciesHz=scene.largeFrequenciesHz; manifest(s).initialCenter=initialCenter; manifest(s).recommendedRoi=recommendedRoi; manifest(s).condition=scene.condition;
end
save(fullfile(cfg.outputRoot,'manifest.mat'),'manifest','scenes','cfg'); write_readme(manifest,cfg.outputRoot);
fprintf('带物体外观的视频已生成：%s\n',cfg.outputRoot);
for s=1:numel(manifest), fprintf('  %s\n',manifest(s).videoPath); end
end

function cfg=default_cfg(outputRoot)
cfg=struct('outputRoot',outputRoot,'width',640,'height',480,'fps',100,'duration_s',10,'numFrames',1000,'quality',92,'randomSeed',20260903, ...
    'baseCenter',[320 240],'roiSide',128,'microFrequencyHz',23,'microXAmplitudePx',0.55,'microYAmplitudePx',0.32, ...
    'objectHubRadiusPx',58,'armLengthPx',145,'armStartPx',15,'boltRadiusPx',42,'markerLengthPx',70,'markerWidthPx',4.2, ...
    'backgroundLevel',0.055,'backgroundTexture',0.012,'noiseSigma',0.004);
end

function scenes=scene_table()
base=struct('name','','largeFrequenciesHz',[],'largeMotionType','','noiseScale',1,'lightChange',0, ...
    'blurSigma',0,'motionBlurSamples',1,'motionBlurExposure',0,'rotationFrequencyHz',0,'rotationAmplitudeDeg',0,'condition','');
scenes=repmat(base,1,4);
scenes(1)=base; scenes(1).name='object_linear_clean'; scenes(1).largeFrequenciesHz=0.8; scenes(1).largeMotionType='linear'; scenes(1).condition='clean';
scenes(2)=base; scenes(2).name='object_linear_light_blur'; scenes(2).largeFrequenciesHz=0.8; scenes(2).largeMotionType='linear'; scenes(2).lightChange=0.25; scenes(2).blurSigma=0.8; scenes(2).motionBlurSamples=5; scenes(2).motionBlurExposure=0.008; scenes(2).condition='illumination + Gaussian/motion blur';
scenes(3)=base; scenes(3).name='object_nonlinear_fast_rotation'; scenes(3).largeFrequenciesHz=[0.55 1.35]; scenes(3).largeMotionType='nonlinear'; scenes(3).rotationFrequencyHz=1.4; scenes(3).rotationAmplitudeDeg=65; scenes(3).noiseScale=1.2; scenes(3).condition='nonlinear motion + high-speed rotation';
scenes(4)=base; scenes(4).name='object_nonlinear_all_conditions'; scenes(4).largeFrequenciesHz=[0.55 1.35]; scenes(4).largeMotionType='nonlinear'; scenes(4).rotationFrequencyHz=1.2; scenes(4).rotationAmplitudeDeg=55; scenes(4).lightChange=0.30; scenes(4).blurSigma=1.0; scenes(4).motionBlurSamples=5; scenes(4).motionBlurExposure=0.008; scenes(4).noiseScale=1.5; scenes(4).condition='nonlinear motion + illumination + blur + rotation';
end

function [center,largeCenter,microCenter,angleDeg]=motion_truth(scene,t,cfg)
microCenter=[cfg.microXAmplitudePx*sin(2*pi*cfg.microFrequencyHz*t),cfg.microYAmplitudePx*cos(2*pi*cfg.microFrequencyHz*t)];
if strcmp(scene.largeMotionType,'linear'), largeX=135*sin(2*pi*0.8*t); else, largeX=110*sin(2*pi*0.55*t)+45*sin(2*pi*1.35*t+0.7); end
largeCenter=cfg.baseCenter+[largeX 0]; center=largeCenter+microCenter;
angleDeg=scene.rotationAmplitudeDeg*sin(2*pi*scene.rotationFrequencyHz*t+0.35);
end

function frame=render_conditioned(scene,t,cfg,frameIndex)
ns=max(1,round(scene.motionBlurSamples)); offsets=linspace(-scene.motionBlurExposure/2,scene.motionBlurExposure/2,ns); image=zeros(cfg.height,cfg.width);
for k=1:ns
    [center,~,~,angleDeg]=motion_truth(scene,t+offsets(k),cfg); image=image+render_object(center,angleDeg,scene,cfg,frameIndex+offsets(k)*cfg.fps);
end
image=image/ns; if scene.blurSigma>0, image=imgaussfilt(image,scene.blurSigma,'Padding','symmetric'); end
noise=cfg.noiseSigma*scene.noiseScale*randn(size(image)); frame=uint8(round(255*min(max(image+noise,0),1)));
end

function image=render_object(center,angleDeg,scene,cfg,frameIndex)
[x,y]=meshgrid(1:cfg.width,1:cfg.height); dx=x-center(1); dy=y-center(2); a=deg2rad(angleDeg);
u=dx*cos(a)+dy*sin(a); v=-dx*sin(a)+dy*cos(a); R=cfg.objectHubRadiusPx;
radial=sqrt(u.^2+v.^2); hub=1./(1+exp((radial-R)/1.8)); armWidth=30-0.10*max(u-cfg.armStartPx,0);
arm=1./(1+exp((cfg.armStartPx-u)/1.8)).*1./(1+exp((u-cfg.armLengthPx)/1.8)).*1./(1+exp((abs(v)-armWidth)/1.8));
% 物体主体保持中低灰度，让白色 crossline 成为 ROI 内唯一的强亮特征，
% 避免 Hough 将机械臂边缘误选为 marker 线；轮毂形状仍由阴影/高光呈现。
shade=0.105+0.018*(u/cfg.armLengthPx)+0.012*cos(2*pi*v/max(R,1)); image=cfg.backgroundLevel+cfg.backgroundTexture*(0.5*sin(2*pi*x/280)+0.5*cos(2*pi*y/210));
objectMask=max(hub,arm); image=image+objectMask.*(shade-image); highlight=exp(-((u+18).^2+(v+12).^2)/(2*22^2)); image=image+0.018*highlight.*hub;
for q=0:3
    b=deg2rad(45+90*q); bu=cfg.boltRadiusPx*cos(b); bv=cfg.boltRadiusPx*sin(b); bolt=((u-bu).^2+(v-bv).^2<=5^2); image(bolt)=0.08;
end
if scene.lightChange~=0, image=image.*(1+scene.lightChange*0.30*sin(2*pi*frameIndex/(cfg.fps*2.4))); end
marker=max(soft_line(x,y,center,angleDeg,cfg.markerWidthPx,cfg.markerLengthPx),soft_line(x,y,center,angleDeg+90,cfg.markerWidthPx,cfg.markerLengthPx)); image=image+marker.*(0.96-image);
end

function lineImage=soft_line(x,y,center,angleDeg,widthPx,lengthPx)
a=deg2rad(angleDeg); dx=x-center(1); dy=y-center(2); u=dx*cos(a)+dy*sin(a); v=-dx*sin(a)+dy*cos(a);
lineImage=(1./(1+exp((abs(v)-widthPx/2)/0.45))).*(1./(1+exp((abs(u)-lengthPx/2)/0.75)));
end

function roi=make_roi(center,cfg)
side=min([cfg.roiSide,cfg.width,cfg.height]); x=round(center(1)-side/2); y=round(center(2)-side/2); x=min(max(1,x),cfg.width-side+1); y=min(max(1,y),cfg.height-side+1); roi=[x y side side];
end

function out=merge_cfg(base,user)
out=base; names=fieldnames(user); for k=1:numel(names), out.(names{k})=user.(names{k}); end
end

function write_readme(manifest,outputRoot)
fid=fopen(fullfile(outputRoot,'README.txt'),'w','n','UTF-8'); if fid<0, return; end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'所有视频：100 fps、10 s、1000 帧；十字固定在圆盘轮毂表面。\n');
fprintf(fid,'启动 run_real_video 时建议 cfg.real.roi=[]，在首帧手动框选包含十字轮毂的方形 ROI。\n\n');
for k=1:numel(manifest)
    fprintf(fid,'%s\n视频: %s\n条件: %s\n大运动频率: %s Hz\n微振动频率: %.2f Hz\n推荐初始 ROI: [%d %d %d %d]\n\n', ...
        manifest(k).name,manifest(k).videoPath,manifest(k).condition,num2str(manifest(k).largeFrequenciesHz),manifest(k).microFrequencyHz,manifest(k).recommendedRoi);
end
end
