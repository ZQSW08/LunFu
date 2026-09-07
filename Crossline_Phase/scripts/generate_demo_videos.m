function manifest = generate_demo_videos(outputRoot, userCfg)
%GENERATE_DEMO_VIDEOS 生成可直接用于 run_real_video 的模拟视频。
%
% 用法：
%   cd('D:\\LunFu\\Crossline_Phase');
%   addpath(genpath(pwd));
%   generate_demo_videos;
%
% 视频为灰度相机风格的 RGB AVI，十字中心带有亚像素振动，并提供：
%   1) clean      清晰十字 + 亚像素振动；
%   2) large_motion 大范围平移/小角度旋转 + 振动；
%   3) noisy      背景纹理、亮度变化和高斯噪声。
% 这些视频只用于验证本工程程序链路，不替代论文原始实验数据。

if nargin < 1 || isempty(outputRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    outputRoot = fullfile(projectRoot, 'outputs', 'demo_videos');
end
if nargin < 2 || isempty(userCfg), userCfg = struct(); end

cfg = default_cfg(outputRoot);
cfg = merge_cfg(cfg, userCfg);
if ~isfolder(cfg.outputRoot), mkdir(cfg.outputRoot); end
rng(cfg.randomSeed, 'twister');

scenes = scene_table();
manifest = repmat(struct('name','','videoPath','','previewPath','','fps',[], ...
    'numFrames',[],'imageSize',[],'recommendedRoi',[],'centerFormula',''), 1, numel(scenes));

for s = 1:numel(scenes)
    scene = scenes(s);
    videoPath = fullfile(cfg.outputRoot, [scene.name '.avi']);
    previewPath = fullfile(cfg.outputRoot, [scene.name '_first_frame.png']);
    writer = VideoWriter(videoPath, 'Motion JPEG AVI');
    writer.FrameRate = cfg.fps;
    writer.Quality = cfg.quality;
    open(writer);
    firstFrame = [];
    centers = zeros(cfg.numFrames, 2);
    angles = zeros(cfg.numFrames, 1);
    for k = 1:cfg.numFrames
        t = (k-1) / cfg.fps;
        [center, angleDeg] = scene_motion(scene, t, cfg);
        frame = render_crossline(center, angleDeg, scene, cfg, k);
        writeVideo(writer, repmat(frame, [1 1 3]));
        if k == 1, firstFrame = frame; end
        centers(k,:) = center;
        angles(k) = angleDeg;
    end
    close(writer);
    imwrite(firstFrame, previewPath);
    recommendedRoi = recommended_roi(cfg, scene);
    sceneMeta = scene; %#ok<NASGU>
    save(fullfile(cfg.outputRoot, [scene.name '_truth.mat']), ...
        'centers','angles','recommendedRoi','sceneMeta','cfg');
    manifest(s).name = scene.name;
    manifest(s).videoPath = videoPath;
    manifest(s).previewPath = previewPath;
    manifest(s).fps = cfg.fps;
    manifest(s).numFrames = cfg.numFrames;
    manifest(s).imageSize = [cfg.height cfg.width];
    manifest(s).recommendedRoi = recommendedRoi;
    manifest(s).centerFormula = scene.centerFormula;
end

save(fullfile(cfg.outputRoot, 'manifest.mat'), 'manifest', 'cfg', 'scenes');
write_manifest_text(manifest, cfg.outputRoot);
fprintf('模拟视频已生成：%s\n', cfg.outputRoot);
for s = 1:numel(manifest)
    fprintf('  %-14s %s\n', [manifest(s).name ':'], manifest(s).videoPath);
end
end

function cfg = default_cfg(outputRoot)
cfg = struct();
cfg.outputRoot = outputRoot;
cfg.width = 640;
cfg.height = 480;
cfg.fps = 100;
cfg.numFrames = 400;
cfg.quality = 92;
cfg.randomSeed = 20260902;
cfg.markerLengthPx = 170;
cfg.markerWidthPx = 4.0;
cfg.backgroundLevel = 0.10;
cfg.backgroundTexture = 0.02;
cfg.noiseSigma = 0.008;
cfg.baseCenter = [320 240];
cfg.roiSide = 240;
end

function scenes = scene_table()
base = struct('name','','amplitudePx',0,'frequencyHz',8,'phaseRad',0, ...
    'translationPx',[0 0],'rotationDeg',0,'noiseScale',1, ...
    'illuminationScale',0,'clutter',false,'centerFormula','');
scenes = repmat(base,1,3);
scenes(1) = base;
scenes(1).name = 'demo_clean_vibration';
scenes(1).amplitudePx = 0.60;
scenes(1).centerFormula = 'x=x0+0.60*sin(2*pi*8*t), y=y0+0.35*cos(2*pi*8*t)';
scenes(2) = base;
scenes(2).name = 'demo_large_motion';
scenes(2).amplitudePx = 0.45;
scenes(2).translationPx = [18 12];
scenes(2).rotationDeg = 7;
scenes(2).frequencyHz = 0.65;
scenes(2).phaseRad = pi/5;
scenes(2).centerFormula = '大范围 x/y 平移、7 度旋转叠加 8 Hz 亚像素振动';
scenes(3) = base;
scenes(3).name = 'demo_noisy_vibration';
scenes(3).amplitudePx = 0.50;
scenes(3).frequencyHz = 8;
scenes(3).noiseScale = 3;
scenes(3).illuminationScale = 0.18;
scenes(3).clutter = true;
scenes(3).centerFormula = '8 Hz 亚像素振动 + 亮度变化 + 背景纹理 + 高斯噪声';
end

function [center, angleDeg] = scene_motion(scene, t, cfg)
center = cfg.baseCenter;
center = center + scene.translationPx .* [sin(2*pi*scene.frequencyHz*t+scene.phaseRad), ...
    cos(2*pi*scene.frequencyHz*t+scene.phaseRad)];
center = center + scene.amplitudePx .* [sin(2*pi*8*t), 0.58*cos(2*pi*8*t)];
angleDeg = scene.rotationDeg * sin(2*pi*scene.frequencyHz*t+scene.phaseRad);
end

function frame = render_crossline(center, angleDeg, scene, cfg, frameIndex)
[x,y] = meshgrid(1:cfg.width, 1:cfg.height);
bg = cfg.backgroundLevel + cfg.backgroundTexture * ...
    (0.55*sin(2*pi*x/(cfg.width*0.8)) + 0.45*cos(2*pi*y/(cfg.height*0.7)));
if scene.illuminationScale ~= 0
    bg = bg + scene.illuminationScale * 0.12 * sin(2*pi*frameIndex/(cfg.numFrames*0.8));
end

% 用平滑有限矩形近似两条印刷线，保留亚像素中心，不做整数平移。
lineA = soft_line(x, y, center, angleDeg, cfg.markerWidthPx, cfg.markerLengthPx);
lineB = soft_line(x, y, center, angleDeg+90, cfg.markerWidthPx, cfg.markerLengthPx);
marker = max(lineA, lineB);
image = bg + marker .* (0.90 - bg);

if scene.clutter
    % 低亮度小纹理不会覆盖十字，只用于测试分割的稳定性。
    image = image + 0.025*sin(2*pi*(x+y)/37) + 0.018*cos(2*pi*(x-2*y)/53);
end
noise = cfg.noiseSigma * scene.noiseScale * randn(size(image));
frame = uint8(round(255 * min(max(image + noise, 0), 1)));
end

function lineImage = soft_line(x, y, center, angleDeg, widthPx, lengthPx)
a = deg2rad(angleDeg);
dx = x - center(1); dy = y - center(2);
u = dx*cos(a) + dy*sin(a);
v = -dx*sin(a) + dy*cos(a);
edgeWidth = 0.45;
across = 1 ./ (1 + exp((abs(v)-widthPx/2)/edgeWidth));
along = 1 ./ (1 + exp((abs(u)-lengthPx/2)/0.75));
lineImage = across .* along;
end

function roi = recommended_roi(cfg, scene)
% 推荐值仅用于方便测试；run_real_video 默认仍要求用户手动框选 ROI。
maxShift = norm(scene.translationPx, inf) + scene.amplitudePx + 4;
side = min([cfg.roiSide, cfg.width, cfg.height]);
cx = cfg.baseCenter(1); cy = cfg.baseCenter(2);
cx = min(max(cx, side/2+1), cfg.width-side/2);
cy = min(max(cy, side/2+1), cfg.height-side/2);
roi = [round(cx-side/2) round(cy-side/2) side side];
if maxShift > side/4
    warning('Crossline:DemoROI','场景 %s 的运动接近 ROI 边界，请手动选择更大的 ROI。',scene.name);
end
end

function out = merge_cfg(base, user)
out = base;
names = fieldnames(user);
for k = 1:numel(names)
    out.(names{k}) = user.(names{k});
end
end

function write_manifest_text(manifest, outputRoot)
fid = fopen(fullfile(outputRoot,'README.txt'),'w','n','UTF-8');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '模拟视频使用说明\n\n');
fprintf(fid, '每个 AVI 均可直接作为 scripts/run_real_video.m 的 cfg.real.videoPath。\n');
fprintf(fid, '启动后在首帧拖动框选包含完整十字的方形 ROI，双击或按 Enter 确认。\n\n');
for k = 1:numel(manifest)
    fprintf(fid, '%s\n  视频: %s\n  推荐 ROI: [%d %d %d %d]\n  真值: %s\n\n', ...
        manifest(k).name, manifest(k).videoPath, manifest(k).recommendedRoi, manifest(k).centerFormula);
end
end
