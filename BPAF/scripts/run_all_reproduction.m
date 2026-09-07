%RUN_ALL_REPRODUCTION 论文《Video-based subtle vibration measurement...》总入口。
% 在 MATLAB 中直接运行本脚本；所有输入、缓存和输出均限制在 BPAF 文件夹。

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot,'src'));
cfg = bpaf.default_config();
results = bpaf.run_all(cfg); %#ok<NASGU>
