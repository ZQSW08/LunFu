close all; clearvars; clc;
root=fileparts(mfilename('fullpath'));addpath(root);u=mfm.real_defaults();

%% 1. 视频与采集设置
u.videoPath='C:/0819/4-25mvpp-motion.avi';
u.outputRoot=fullfile(root,'outputs','baseline_user');
u.captureFPS=100;
u.maxFrames=Inf;
u.axis='x';

%% 2. 双 ROI 基线路径：依次框选目标和随同大运动的刚性参考
u.roiMode='interactive';
u.targetROI=[];                 % manual模式填写[x y width height]
u.referenceSelection='interactive';
u.referenceROIs=[];             % manual模式每行一个参考
u.referenceModel='translation'; % 有旋转且至少两个参考时用similarity
u.targetMode='profile';
u.referenceTracker='anchor';
u.autoProfileRows=true;
u.maxSamples=6500;

%% 3. 同时保留原始测量和旧版诊断图
u.analysisBandHz=[2 45];        % 通用显示范围，应低于captureFPS/2
u.denoise=true;                % 稳定模态诊断；不会替代原始相对位移
u.showFigures=true;
u.exportFigures=true;
result=run_real_video(u);
% 02/03为原始结果；04为可选宽带/模态图。缺测不插值。
