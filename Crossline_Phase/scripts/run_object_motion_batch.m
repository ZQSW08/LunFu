function resultDirs = run_object_motion_batch(resultRoot, maxJumpPx, videoRoot)
%RUN_OBJECT_MOTION_BATCH 批量处理四类具象物体模拟视频。
% 使用生成器保存的推荐 ROI，便于重复评测速度和精度；真实视频仍建议手动框选 ROI。
close all; clc;
scriptPath = fileparts(mfilename('fullpath')); projectRoot = fileparts(scriptPath);
addpath(fullfile(projectRoot,'config')); addpath(genpath(fullfile(projectRoot,'src')));
addpath(genpath(fullfile(projectRoot,'simulation'))); addpath(genpath(fullfile(projectRoot,'third_party','matlabPyrTools')));
if nargin < 3 || isempty(videoRoot), videoRoot = fullfile(projectRoot,'outputs','object_motion_videos'); end
if nargin < 1 || isempty(resultRoot), resultRoot = fullfile(projectRoot,'outputs','object_motion_results_final128'); end
if nargin < 2 || isempty(maxJumpPx), maxJumpPx = []; end
if ~isfolder(resultRoot), mkdir(resultRoot); end
names = {'object_linear_clean','object_linear_light_blur','object_nonlinear_fast_rotation','object_nonlinear_all_conditions'};
roiList = {[256 176 128 128],[256 176 128 128],[285 176 128 128],[285 176 128 128]};
resultDirs = cell(size(names));
for i = 1:numel(names)
    cfg = config_default(projectRoot);
    cfg.real.videoPath = fullfile(videoRoot,[names{i} '.avi']);
    cfg.real.outputName = fullfile(resultRoot,names{i});
    cfg.real.roi = roiList{i}; cfg.real.maxFrames = Inf; cfg.real.fpsOverride = 100;
    cfg.real.fastMode = true; cfg.real.rejectLargeJumps = true; cfg.real.maxFrameJumpPx = maxJumpPx;
    cfg.real.useVelocityPrediction = false;
    cfg.real.expectedFrequenciesHz = 23;
    % 模拟物体的十字是明确的白色标记，避免机械臂/螺栓纹理干扰粗分割。
    cfg.coarse.brightMarkerThreshold = 0.55;
    cfg.real.saveProcessImages = false;
    run_real_video(cfg);
    d = dir([cfg.real.outputName '_*']); d = d([d.isdir]); [~,ix] = max([d.datenum]);
    resultDirs{i} = fullfile(d(ix).folder,d(ix).name);
end
save(fullfile(resultRoot,'batch_result_dirs.mat'),'resultDirs','names','roiList');
fprintf('四类物体视频处理完成，结果根目录：%s\n',resultRoot);
end
