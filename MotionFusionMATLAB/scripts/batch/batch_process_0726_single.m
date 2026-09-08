%% 07-26_single 视频批处理
% 逐行注释 videoFiles 中的路径即可控制运行的视频。
% 处理流程调用项目自己的 run_real_video，不使用外部传感器或先验频率。
close all; clearvars; clc;
scriptRoot=fileparts(mfilename('fullpath'));
projectRoot=fileparts(fileparts(scriptRoot));
addpath(fullfile(projectRoot,'src'));

%% 1. 输入视频与批处理输出
videoFiles={
    'D:\07-26_single\kuai-buqiao.avi';
    'D:\07-26_single\kuai-qiao.avi';
    'D:\07-26_single\luandong-buqiao.avi';
    'D:\07-26_single\luandong-qiao.avi';
    'D:\07-26_single\man-buqiao.avi';
    'D:\07-26_single\man-qiao.avi';
    'D:\07-26_single\static-qiao.avi';
};
outputRoot=fullfile(projectRoot,'outputs','batch_0726_single');

%% 2. 第一帧目标 ROI（与参考 ROI 配置相互独立）
roiMode= 'interactive';                 % interactive 框选 / manual 手填 / saved 读取
targetROI= [];                           % manual时：[x y width height]
roiSource= '';                           % saved时：ROI文件路径

%% 3. 宏观运动参考
referenceModel= 'none';           % translation 一个参考 / similarity 至少两个参考 / none 无参考
referenceSelection= 'interactive';      % interactive 框选参考 / manual 使用 referenceROIs
referenceROIs= [];                       % manual 时每行一个[x y width height]
% none只输出目标总位移；translation需要框选一个随宏观运动的刚性参考。

%% 4. 图像配准（所有视频使用同一配置）
targetMode= 'direct';                    % direct 一致目标配准 / profile 旧方法 / consensus 实验 / texture 双向
referenceTracker= 'flow';                % flow 双向光流参考 / anchor 旧固定模板
axis= 'x';                               % 按物理方向选择 x 或 y
captureFPS= 100;                          % []使用视频元数据；明确填写时使用指定采样率
maxFrames= Inf;                          % Inf处理完整视频；可填整数做快速检查
maxSamples= 6500;                        % 固定通用设置，不随视频名称变化
autoProfileRows= true;                   % 仅用第一帧确定目标测量支持

%% 5. 输出（主结果保持原始测量）
analysisBandHz= [4 10];                     % [] 不带通；明确设置频带才生成额外诊断图
denoise= true;                          % 保持 false ；启用时必须先填写 analysisBandHz
showFigures=false;                       % 保存的FIG保持 visible=on
exportFigures= true;
exportTrackingVideo= false;              % 独立追踪视频，不计入算法耗时

%% 6. 批处理执行
for k=1:numel(videoFiles)
    videoPath=videoFiles{k};
    if ~isfile(videoPath), warning('跳过不存在的视频：%s',videoPath); continue; end
    [~,name]=fileparts(videoPath);
    fprintf('\n=== [%d/%d] %s ===\n',k,numel(videoFiles),name);
    u=mfm.real_defaults();
    u.videoPath=videoPath; u.outputRoot=outputRoot;
    u.captureFPS=captureFPS; u.maxFrames=maxFrames; u.axis=axis;
    u.roiMode=roiMode; u.targetROI=targetROI; u.roiSource=roiSource;
    u.referenceModel=referenceModel; u.referenceSelection=referenceSelection; u.referenceROIs=referenceROIs;
    u.targetMode=targetMode; u.referenceTracker=referenceTracker;
    u.autoProfileRows=autoProfileRows; u.maxSamples=maxSamples;
    u.analysisBandHz=analysisBandHz; u.denoise=denoise;
    u.showFigures=showFigures; u.exportFigures=exportFigures; u.exportTrackingVideo=exportTrackingVideo;
    run_real_video(u);
end
fprintf('\n07-26_single批处理完成。\n');



