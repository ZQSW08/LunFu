%RUN_USER_VIDEO 对用户后续提供的真实视频运行完整 BPAF。
% 修改下方参数后运行；原视频不会被覆盖。
close all; clearvars; clc; warning off;

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot,'src'));
cfg = bpaf.default_config();
bpaf.setup_project(cfg);

videoFile = fullfile(projectRoot,'data','input','user_video.avi');
fps = 200;
frequencyBandHz = [20 50];
analysisStartSeconds = 0;
analysisDurationSeconds = 4;

assert(isfile(videoFile), '请先把真实视频放到：%s', videoFile);
reader = VideoReader(videoFile);
reader.CurrentTime = analysisStartSeconds;
nFrames = min(round(analysisDurationSeconds*fps),floor((reader.Duration-analysisStartSeconds)*fps));
first = readFrame(reader);
if size(first,3)==3, first=rgb2gray(first); end
first = im2single(first);
frames = zeros(size(first,1),size(first,2),nFrames,'single');
frames(:,:,1)=first;
for idx=2:nFrames
    frame=readFrame(reader);
    if size(frame,3)==3, frame=rgb2gray(frame); end
    frames(:,:,idx)=im2single(frame);
end
spec=struct('id','USER_VIDEO','fs',fps,'duration',nFrames/fps,'targetFrequency',NaN, ...
    'description','用户真实视频','height',size(frames,1),'width',size(frames,2), ...
    'analyzeStart',0,'analyzeDuration',nFrames/fps,'proxy',false,'targetType','unknown');
truth=struct('time',(0:nFrames-1)'/fps,'largeMotionPx',nan(nFrames,1), ...
    'vibrationPx',zeros(nFrames,1),'totalMotionPx',nan(nFrames,1),'fs',fps, ...
    'targetFrequency',NaN,'proxy',false,'description','未知真值');
data=struct('frames',frames,'truth',truth,'spec',spec);
cfg.forceReextract=true;
features=bpaf.extract_phase_features(data,cfg);
result=bpaf.run_method(features,'BPAF',frequencyBandHz,cfg,'cube',true);
save(fullfile(cfg.resultDir,'user_video_result.mat'),'result','frequencyBandHz','videoFile','-v7.3');
figure; plot(result.metrics.frequency,result.metrics.spectrum); grid on;
xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); title('BPAF spectrum');
