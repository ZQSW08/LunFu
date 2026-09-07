close all; clearvars; clc;
root=fileparts(mfilename('fullpath'));addpath(root);u=mfm.real_defaults();

%% 1. 输入、输出与采样率
u.videoPath='C:\0819\4-25mvpp-motion.avi';
u.outputRoot= 'D:\LunFu\MotionFusionMATLAB\outputs'; % 自动追加视频名，旧结果归档
u.captureFPS=100;            % 实际采集帧率；[]才使用文件元数据
u.maxFrames=Inf;             % 200可检查跟踪，但不能证明全视频成功
u.axis='x';                 % 按实验物理方向选 x / y，不能根据哪个峰好看改方向

%% 2. 第一帧目标 ROI（与参考 ROI 配置相互独立）
u.roiMode='interactive';    % interactive框选 / manual手填 / saved读几何
u.targetROI=[];             % manual时：[x y width height]，坐标从1开始
u.roiSource='';             % saved时：只读MAT里的roi字段，其他模式不读取MPME

%% 3. 宏观运动参考
u.referenceModel='translation'; % translation（一个参考） / similarity(至少两个参考) / 无参考 none
u.referenceSelection='interactive'; % interactive框选参考 / manual使用下行坐标
u.referenceROIs=[];          % 手填时每行一个[x y w h]；没有自动继承旧视频参考
% none必须配合空referenceROIs：只测目标总位移，不能当作宏观运动已分离。
% 参考离开视野后，仍导出目标总位移；相对位移保留NaN。

%% 4. 图像配准（所有视频相同规则；目前仍属于待验精度的候选实现）
u.targetMode='profile';    % direct 一致目标配准 / profile 旧方法 / consensus 实验 / texture 双向
u.referenceTracker='flow';   % flow 双向光流参考 / anchor 旧固定模板
u.autoProfileRows=true;      % 仅用第一帧，在已选目标框内确定测量支持
u.maxSamples=6500;           % 固定通用设置，不随视频名字变化

%% 5. 输出：主结果始终为未经时域滤波的测量
u.analysisBandHz=[];         % []不带通；明确设置频带才生成额外诊断图
u.denoise=false;             % 保持false：不选峰、不窄带重构
u.showFigures=true;          % 保存的FIG始终Visible=on
u.exportFigures=true;
u.exportTrackingVideo=true;     % 独立导出 tracking_overlay.avi，不计入算法耗时

result=run_real_video(u);
% 优先检查02_waveform中的总位移、参考位移、原始相对位移和有效性。
% 有效率不等于精度；三角光只能在预测固定后交给独立评价脚本。
