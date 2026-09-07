%RUN_ALL_REPRODUCTION 一键运行 AP-CV 论文完整等价合成复现。
% 真实实验原视频和 LDV 数据未公开，因此本脚本验证完整算法链及论文全部对照，
% 但输出必须表述为 synthetic equivalent reproduction。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot,'src'));
addpath(fullfile(projectRoot,'configs'));
addpath(fullfile(projectRoot,'third_party','matlabPyrTools'));

cfg = apcv_default_config(projectRoot);
summary = apcv_run_reproduction(cfg); %#ok<NASGU>
