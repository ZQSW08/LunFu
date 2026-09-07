function manifest = generate_motion_test_videos(outputRoot, userCfg)
%GENERATE_MOTION_TEST_VIDEOS 生成 100 fps、10 s 的大运动测试视频。
%
% 两个场景均为水平运动，并叠加已知的 23 Hz 微振动：
%   linear   : x=x0+135*sin(2*pi*0.8*t)+0.55*sin(2*pi*23*t)
%   nonlinear: x=x0+110*sin(2*pi*0.55*t)+45*sin(2*pi*1.35*t+0.7)
%                         +0.55*sin(2*pi*23*t)
% 其中所有大运动频率均不超过 2 Hz。输出视频可直接交给 run_real_video。
%
% 用法：
%   cd('D:\\LunFu\\Crossline_Phase'); addpath(genpath(pwd));
%   generate_motion_test_videos;

if nargin < 1 || isempty(outputRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    outputRoot = fullfile(projectRoot, 'outputs', 'motion_test_videos');
end
if nargin < 2 || isempty(userCfg), userCfg = struct(); end
cfg = default_cfg(outputRoot);
cfg = merge_cfg(cfg, userCfg);
if ~isfolder(cfg.outputRoot), mkdir(cfg.outputRoot); end
rng(cfg.randomSeed, 'twister');

scenes = scene_table();
manifest = repmat(struct('name','','videoPath','','truthPath','','previewPath','', ...
    'fps',cfg.fps,'duration_s',cfg.numFrames/cfg.fps,'numFrames',cfg.numFrames, ...
    'largeFrequenciesHz',[],'microFrequencyHz',cfg.microFrequencyHz, ...
    'initialCenter',[],'recommendedRoi',[]),1,numel(scenes));

for s = 1:numel(scenes)
    scene = scenes(s);
    videoPath = fullfile(cfg.outputRoot, [scene.name '.avi']);
    truthPath = fullfile(cfg.outputRoot, [scene.name '_truth.mat']);
    previewPath = fullfile(cfg.outputRoot, [scene.name '_first_frame.png']);
    writer = VideoWriter(videoPath, 'Motion JPEG AVI');
    writer.FrameRate = cfg.fps; writer.Quality = cfg.quality; open(writer);
    centers = zeros(cfg.numFrames,2); largeCenters = zeros(cfg.numFrames,2);
    microCenters = zeros(cfg.numFrames,2); angles = zeros(cfg.numFrames,1);
    firstFrame = [];
    for k = 1:cfg.numFrames
        t = (k-1)/cfg.fps;
        [center,largeCenter,microCenter,angleDeg] = motion_truth(scene,t,cfg);
        frame = render_frame(center,angleDeg,scene,cfg,k);
        writeVideo(writer,repmat(frame,[1 1 3]));
        if k==1, firstFrame=frame; end
        centers(k,:) = center; largeCenters(k,:) = largeCenter;
        microCenters(k,:) = microCenter; angles(k) = angleDeg;
    end
    close(writer); imwrite(firstFrame,previewPath);
    time = (0:cfg.numFrames-1)'/cfg.fps; %#ok<NASGU>
    initialCenter = centers(1,:); %#ok<NASGU>
    recommendedRoi = make_roi(initialCenter,cfg); %#ok<NASGU>
    sceneMeta = scene; %#ok<NASGU>
    save(truthPath,'time','centers','largeCenters','microCenters','angles', ...
        'initialCenter','recommendedRoi','sceneMeta','cfg');
    writetable(table((1:cfg.numFrames)',time,centers(:,1),centers(:,2), ...
        largeCenters(:,1),largeCenters(:,2),microCenters(:,1),microCenters(:,2),angles, ...
        'VariableNames',{'frame','time_s','truth_x','truth_y','large_x','large_y', ...
        'micro_x','micro_y','angle_deg'}), ...
        fullfile(cfg.outputRoot,[scene.name '_truth.csv']));

    manifest(s).name=scene.name; manifest(s).videoPath=videoPath;
    manifest(s).truthPath=truthPath; manifest(s).previewPath=previewPath;
    manifest(s).largeFrequenciesHz=scene.largeFrequenciesHz;
    manifest(s).initialCenter=initialCenter; manifest(s).recommendedRoi=recommendedRoi;
end
save(fullfile(cfg.outputRoot,'manifest.mat'),'manifest','scenes','cfg');
write_readme(manifest,cfg.outputRoot);
fprintf('大运动测试视频已生成：%s\n',cfg.outputRoot);
for s=1:numel(manifest)
    fprintf('  %s\n',manifest(s).videoPath);
end
end

function cfg = default_cfg(outputRoot)
cfg=struct('outputRoot',outputRoot,'width',640,'height',480,'fps',100, ...
    'duration_s',10,'numFrames',1000,'quality',92,'randomSeed',20260902, ...
    'markerLengthPx',180,'markerWidthPx',4.2,'backgroundLevel',0.10, ...
    'backgroundTexture',0.018,'noiseSigma',0.006,'baseCenter',[320 240], ...
    'roiSide',260,'microFrequencyHz',23,'microXAmplitudePx',0.55, ...
    'microYAmplitudePx',0.32);
end

function scenes=scene_table()
base=struct('name','','largeFrequenciesHz',[],'largeMotionType','', ...
    'noiseScale',1,'illuminationScale',0,'rotationAmplitudeDeg',0,'description','');
scenes=repmat(base,1,2);
scenes(1)=base; scenes(1).name='horizontal_linear_large_motion';
scenes(1).largeFrequenciesHz=0.8; scenes(1).largeMotionType='linear_sinusoid';
scenes(1).noiseScale=1; scenes(1).description='水平 0.8 Hz 大幅正弦运动 + 23 Hz 微振动';
scenes(2)=base; scenes(2).name='horizontal_nonlinear_large_motion';
scenes(2).largeFrequenciesHz=[0.55 1.35]; scenes(2).largeMotionType='nonlinear_two_frequency';
scenes(2).noiseScale=1.5; scenes(2).illuminationScale=0.10;
scenes(2).rotationAmplitudeDeg=0; scenes(2).description='水平 0.55 Hz 与 1.35 Hz 复合大运动 + 23 Hz 微振动';
end

function [center,largeCenter,microCenter,angleDeg]=motion_truth(scene,t,cfg)
x0=cfg.baseCenter(1); y0=cfg.baseCenter(2);
microCenter=[cfg.microXAmplitudePx*sin(2*pi*cfg.microFrequencyHz*t), ...
    cfg.microYAmplitudePx*cos(2*pi*cfg.microFrequencyHz*t)];
switch scene.largeMotionType
    case 'linear_sinusoid'
        largeX=135*sin(2*pi*0.8*t); angleDeg=0;
    otherwise
        largeX=110*sin(2*pi*0.55*t)+45*sin(2*pi*1.35*t+0.7);
        angleDeg=scene.rotationAmplitudeDeg*sin(2*pi*0.55*t+0.4);
end
largeCenter=[x0+largeX,y0]; center=largeCenter+microCenter;
end

function frame=render_frame(center,angleDeg,scene,cfg,frameIndex)
[x,y]=meshgrid(1:cfg.width,1:cfg.height);
bg=cfg.backgroundLevel+cfg.backgroundTexture*(0.55*sin(2*pi*x/(cfg.width*0.8))+ ...
    0.45*cos(2*pi*y/(cfg.height*0.7)));
if scene.illuminationScale~=0
    bg=bg+scene.illuminationScale*0.12*sin(2*pi*frameIndex/cfg.numFrames);
end
line1=soft_line(x,y,center,angleDeg,cfg.markerWidthPx,cfg.markerLengthPx);
line2=soft_line(x,y,center,angleDeg+90,cfg.markerWidthPx,cfg.markerLengthPx);
marker=max(line1,line2); image=bg+marker.*(0.90-bg);
noise=cfg.noiseSigma*scene.noiseScale*randn(size(image));
frame=uint8(round(255*min(max(image+noise,0),1)));
end

function lineImage=soft_line(x,y,center,angleDeg,widthPx,lengthPx)
a=deg2rad(angleDeg); dx=x-center(1); dy=y-center(2);
u=dx*cos(a)+dy*sin(a); v=-dx*sin(a)+dy*cos(a);
across=1./(1+exp((abs(v)-widthPx/2)/0.45));
along=1./(1+exp((abs(u)-lengthPx/2)/0.75));
lineImage=across.*along;
end

function roi=make_roi(center,cfg)
side=min([cfg.roiSide,cfg.width,cfg.height]);
x=round(center(1)-side/2); y=round(center(2)-side/2);
x=min(max(1,x),cfg.width-side+1); y=min(max(1,y),cfg.height-side+1);
roi=[x y side side];
end

function out=merge_cfg(base,user)
out=base; names=fieldnames(user);
for k=1:numel(names), out.(names{k})=user.(names{k}); end
end

function write_readme(manifest,outputRoot)
fid=fopen(fullfile(outputRoot,'README.txt'),'w','n','UTF-8');
if fid<0, return; end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'所有视频：100 fps、10 s、1000 帧；微振动频率固定为 23 Hz。\n');
fprintf(fid,'run_real_video 默认仍建议 cfg.real.roi=[]，由用户在首帧手动框选。\n\n');
for k=1:numel(manifest)
    fprintf(fid,'%s\n视频: %s\n真值: %s\n推荐初始 ROI: [%d %d %d %d]\n大运动频率: %s Hz\n微振动频率: %.2f Hz\n\n', ...
        manifest(k).name,manifest(k).videoPath,manifest(k).name,manifest(k).recommendedRoi, ...
        num2str(manifest(k).largeFrequenciesHz),manifest(k).microFrequencyHz);
end
end
