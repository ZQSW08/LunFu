function setup_project(cfg)
% SETUP_PROJECT 加载当前 PLT 工程的路径。
% matlabPyrTools 已按用户要求复制到当前工程，V1 的 Gabor 实现本身不强依赖它；
% 加入路径是为了后续 steerable/金字塔扩展时保持工程自包含。

% 放在路径首位，避免同时打开其他论文工程时调用到同名旧函数。
addpath(fullfile(cfg.projectRoot, 'src'), '-begin');
toolboxRoot = fullfile(cfg.projectRoot, 'third_party', 'matlabPyrTools');
if isfolder(toolboxRoot)
    addpath(genpath(toolboxRoot), '-begin');
end
end
