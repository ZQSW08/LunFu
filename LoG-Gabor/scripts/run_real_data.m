% RUN_REAL_DATA 当前 LoG-Gabor 论文的真实视频入口。
% 只修改下面“用户配置”区域；核心算法位于 src/，不要在本脚本中改公式。
% ROI 格式为 [x y width height]；[] 表示运行时在首帧上交互选择。

close all; clearvars; clc;
scriptPath=mfilename('fullpath'); projectRoot=fileparts(fileparts(scriptPath));
addpath(genpath(fullfile(projectRoot,'src'))); addpath(fullfile(projectRoot,'configs'));

%% 用户配置：真实运行前只需要修改这里
config.videoPath= 'C:\0819\4-25mvpp-static.avi';
config.outputDirectory= 'D:\LunFu\LoG-Gabor\outputs\0819\4-25mvpp-static';
% config.outputName='4-25mvpp-static';
config.roi=[];                         % [x y width height]；[]=首帧交互
config.maxFrames= 300;                  % 真实入口默认先处理前 300 帧；确认内存后再改为 Inf
config.startFrame= 1;
config.endFrame= Inf;
config.fpsOverride= 100;                 % []=使用视频元数据帧率

% 本论文专属配置：真实首帧训练 + Log-Gabor/PME/full-field ODS
config.method.theta0=pi/2;             % 垂直运动；水平运动使用 0
config.method.maxTasks=8;              % 真实视频默认轻量；确认后可增大
config.method.taskPixels=[];           % []=从 active mask 自动选择 [row col]
config.method.trainingFrames=60;       % 训练帧数，不等于真实视频帧数
config.method.trainingFrequency=5;     % Hz，必须低于视频 Nyquist
config.method.trainingAmplitude=.10;   % pixel，训练运动，不是真实振幅
config.method.populationSize=5;        % 真实入口默认轻量 MaTO
config.method.generations=8;
config.method.maxObjectiveEvaluations=2000; % 超过则先提示，避免无提示长时间运行
config.method.maxTrainingPixels=262144; % ROI 训练面积上限，约 512×512
config.method.allowLargeTraining=false; % 大 ROI 必须显式打开
config.method.useMaTO=true;
config.method.targetFrequency=NaN;      % NaN=从代表性 PME 自动估计
config.method.instantFrame=[];         % []=处理后视频中间帧

% 输出安全选项：ROI 确认后才可能清理同名结果目录
config.output.clearPreviousResults=false;
config.output.saveTrainingVideo=false;
config.output.saveVideoInMat=false;    % 原始视频通常很大，默认不重复写入 MAT

summary=run_real_video(config);
if isfield(summary,'cancelled') && summary.cancelled, return; end
disp(summary);
