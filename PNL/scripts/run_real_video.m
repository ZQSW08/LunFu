%RUN_REAL_VIDEO 真实视频用户配置脚本（单目优先，双目兼容）。
%
% 使用方法：
%   1. 只修改下面“用户配置区”的路径和参数；
%   2. 运行本脚本；
%   3. 结果自动保存到 outputs/real/ 下的独立目录。
%
% 单目模式只需要 videoPath，不需要标定文件，输出二维像素位移、PNL
% 和相位梯度。双目模式再填写 rightVideoPath 和 calibrationFile，保留
% 双目三角测量、局部坐标和三维位移输出。

close all;
clc;

% ===== 1. 工程路径 =====
scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'scripts'));

% ===== 2. 用户配置区：只修改这一段 =====
config.mode = 'mono';    % 'mono'、'stereo' 或 'auto'
config.videoPath = 'C:\0819\4-25mvpp-static.avi';  % 单目视频，或双目左视频
config.rightVideoPath = '';                            % 双目右视频；单目留空
config.calibrationFile = '';            % 双目 MAT：P{1}/P{2}、P1/P2 或 stereoParams

config.outputDirectory = 'D:\LunFu\PNL\outputs\0819\4-25mvpp-static';  % 留空则自动生成独立时间目录
config.roi = [];                        % [x y width height]；留空首帧框选，双击/Enter确认，Esc取消
config.initialPoint = [];               % 单目 [u;v]；仅作参考，留空自动选 ROI 内纹理点
config.initialPoints = [];              % 双目 2x2；每列是一台相机的原始图像 [u;v]
config.startFrame = 1;                  % 从第几帧开始读，MATLAB 采用 1-based
config.frameOffset = 0;                 % 双目右视频相对左视频的帧偏移，正值跳过右视频
config.maxFrames = Inf;                 % 实际处理帧数；Inf 读完整视频但可能占用大量内存
config.fpsOverride = 100;               % 留空使用视频元数据；修改后时间轴按此帧率计算
config.memoryBudgetGB = 2;              % 预估超限时提前停止，避免 MATLAB 直接内存不足
config.analysisDirection = 'both';      % 单目分析方向：'x'水平/u、'y'垂直/v 或 'both'

config.filter = 'geometry';             % 'geometry' 或 'generic'
config.runGeneric = true;               % 是否同时保存 generic 对照
config.worldScale = 1;                  % 例如标定单位 m 转 mm 使用 1000
config.localRotation = eye(3);          % 全局坐标到局部坐标的旋转矩阵
config.localOrigin = [];                % 双目局部原点；留空使用首帧三角测量点
config.keepFlowFields = false;          % 是否保留大体积逐像素光流

% ===== 3. 输入检查与运行 =====
if isempty(config.videoPath)
    error('请先在用户配置区填写 config.videoPath。');
end

fprintf('Starting PNL real-video entry in %s mode.\n', config.mode);
out = run_real_video_entry(config);

fprintf('Finished. Output directory:\n%s\n', out.outputDirectory);
