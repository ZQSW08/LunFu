%RUN_REAL_VIDEO TDDM 真实视频运行脚本。
% 只修改下面的用户配置，然后直接运行本脚本。
close all; clearvars; clc;

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(genpath(fullfile(projectRoot,'src')));
addpath(genpath(fullfile(projectRoot,'config')));

%% 用户配置
config.videoPath = 'D:\实验室\风扇\1-1.mp4';                         % 真实视频绝对路径
% config.outputName = '';                        % 空值：使用视频文件名
config.outputDirectory = 'D:\LunFu\TDDM\results\实验室\风扇\1-1';                   % 非空时就是本次结果目录，不再拼接 outputName
config.roi = [];                               % []：首帧交互框选 [x y width height]
config.selectROI = true;                       % 需要用户框选时保持 true
config.maxFrames = Inf;                        % Inf：处理全部可读帧
config.fpsOverride = [];                        % []：使用视频原始帧率；只有已知采集率时才覆盖
config.markerDiameterPx = 8;                   % 真实视频的标记像素直径
config.detectorMode = 'texture';               % 无圆形标记用局部纹理 NCC；圆标记才使用 circle
config.textureSearchRadiusPx = 8;              % 非圆形目标局部搜索半径（越大越慢）
config.followROI = true;                        % ROI 随 TDDM 最终位置平移
config.clearPreviousResults = true;            % ROI 确认后才清理本次输出目录
config.writeROIVideo = true;                   % 保存随目标跟随的 ROI 裁剪视频
config.writeTrackingVideo = true;              % 保存原图上的跟随框和测点标注视频
config.saveProcess = true;                     % 保存代表性过程图
config.processFrames = [];                     % []：首帧、中帧、末帧
config.runBaselines = false;                   % true：额外运行 KLT/Detection 对照
config.useADIC2D = false;                      % true：启用 ADIC2D 适配器交叉验证
config.pxPerMM = NaN;                          % 无标定时改为 NaN，只输出 pixel 有标定改为具体值
config.analysisAxes = 'xy';                     % 'x'、'y' 或 'xy'
config.spectrumMaxHz = 50;                      % 频谱显示上限，实际不超过 Nyquist 频率
config.spectrumLegend = 'TDDM visual displacement'; % 图例；当前输出是位移而非加速度
config.progressEveryFrames = 25;                % 每隔多少帧打印一次进度
config.showProgress = true;                     % 显示 TDDM 处理进度

if isempty(config.videoPath)
    error('请先在脚本顶部填写 config.videoPath。');
end

%% 执行本论文方法
result = run_tddm_real_video(config);
if isfield(result,'cancelled') && result.cancelled
    disp('ROI 已取消，未清理旧结果目录。');
else
    fprintf('TDDM 真实视频处理完成：%s\n', result.outputRoot);
end
