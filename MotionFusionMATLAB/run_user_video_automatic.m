close all; clearvars; clc;
root=fileparts(mfilename('fullpath'));addpath(root);u=mfm.real_defaults();

%% 1. 输入输出与实际采集设置
u.videoPath='C:/0819/4-25mvpp-motion.avi';
u.outputRoot=fullfile(root,'outputs','automatic_user');
u.captureFPS=100;
u.maxFrames=Inf;
u.axis='x';

%% 2. 框选目标，参考小块由第一帧自动寻找
u.roiMode='interactive';
u.targetROI=[];             % manual时填[x y width height]
u.referenceSelection='automatic';
u.referenceModel='translation';
u.referenceROIs=[];
u.searchROI=[];             % []全图；也可填写同一运动部件的粗范围[x y w h]
% 搜索范围内大多数候选应属于同一宏观运动体。不要混入另一个运动物体。
% 自动模式目前拟合平移；明显旋转请用双/多参考baseline入口的similarity。

%% 3. 测量与输出
u.targetMode='profile';
u.referenceTracker='anchor';
u.autoProfileRows=true;
u.analysisBandHz=[];        % 原始测量；[2 45]可增加宽带诊断
u.denoise=false;
u.showFigures=true;
u.exportFigures=true;
u.exportTrackingVideo=true;
result=run_real_video(u);
% 首帧图检查目标和自动候选；traces.csv查看reference_status与共识支持数。
