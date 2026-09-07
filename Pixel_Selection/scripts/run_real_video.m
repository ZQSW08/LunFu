% RUN_REAL_VIDEO 使用当前论文的方法处理一个真实视频。
% 本脚本是用户入口：只需修改下方配置，再运行本文件即可。
% 真实视频采用固定ROI；关闭ROI窗口或按Esc取消时，不会删除历史结果。
% 论文核心算法位于src/，本文件不混入其他论文的运动模型或滤波流程。

close all; clearvars; clc;

% 工程路径由脚本位置推导，避免依赖其他论文目录或当前工作目录。
scriptPath = mfilename('fullpath');
scriptRoot = fileparts(scriptPath);
projectRoot = fileparts(scriptRoot);
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(genpath(fullfile(projectRoot, 'configs')));

toolboxRoot = fullfile(projectRoot, 'third_party', 'matlabPyrTools');
if ~exist(toolboxRoot, 'dir')
    error('未找到matlabPyrTools目录：%s', toolboxRoot);
end
addpath(genpath(toolboxRoot));
addpath(fullfile(toolboxRoot, 'MEX'), '-begin');

%% 用户配置区：真实使用时只需修改这里
config.videoPath = 'C:\0819\4-25mvpp-static.avi';
config.outputDirectory = 'D:\LunFu\Pixel_Selection\outputs\0819\4-25mvpp-static';
config.outputName = '4-25mvpp-static';

% []表示显示首帧交互选择ROI；也可直接填写[x,y,width,height]。
config.roi = [];
config.maxFrames = Inf;       % Inf表示读取视频中全部可读帧
config.fpsOverride = 100;        % []使用视频元数据帧率，不改变原始帧序列

% x为水平方向，y为垂直方向，auto按CSP方向平均幅值自动选择。
config.direction = 'x';

% 输出设置。无压缩AVI不依赖Motion-JPEG解码器，适合检查ROI内容。
config.output.writeRoiAvi = true;
config.output.clearPreviousResults = false;

%% 执行入口
if isempty(strtrim(config.videoPath))
    error('请先在本文件顶部填写config.videoPath。');
end
result = px_run_real_video_config(config, projectRoot);
