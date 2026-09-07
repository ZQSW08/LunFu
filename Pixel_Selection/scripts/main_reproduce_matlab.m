function result = main_reproduce_matlab(outputRoot, frameCount)
% MATLAB复现主入口：生成合成视频并运行论文方法全流程。
% 使用方式：
%   result = main_reproduce_matlab('D:\\LunFu\\Pixel_Selection\\outputs\\synthetic_equivalent', 300);
scriptRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptRoot);
if nargin < 1 || isempty(outputRoot)
    outputRoot = fullfile(projectRoot, 'outputs', 'synthetic_equivalent');
end
if nargin < 2 || isempty(frameCount)
    frameCount = 300;
end

toolboxRoot = fullfile(projectRoot, 'third_party', 'matlabPyrTools');
if ~exist(toolboxRoot, 'dir')
    error('未找到matlabPyrTools目录：%s', toolboxRoot);
end
addpath(genpath(toolboxRoot));
addpath(fullfile(toolboxRoot, 'MEX'), '-begin');
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(genpath(fullfile(projectRoot, 'configs')));

cfg = px_default_config();
cfg.synthetic.frames = frameCount;
[video, truth] = px_generate_synthetic_video(cfg);
result = px_run_pipeline(video, truth.fs, outputRoot, truth, cfg, 'synthetic');
disp('MATLAB合成等价复现已完成。');
disp(result);
end
