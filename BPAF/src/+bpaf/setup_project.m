function setup_project(cfg)
%SETUP_PROJECT 创建输出目录并加载复可转向金字塔依赖。

folders = {cfg.dataDir, cfg.figureDir, cfg.processDir, cfg.videoDir, ...
    cfg.tableDir, cfg.resultDir};
for idx = 1:numel(folders)
    if ~isfolder(folders{idx})
        mkdir(folders{idx});
    end
end

pyrRoot = fullfile(cfg.projectRoot, 'third_party', 'matlabPyrTools');
assert(isfolder(pyrRoot), '未找到 matlabPyrTools：%s', pyrRoot);
% 使用 genpath 覆盖工具箱的子目录，确保 buildSCFpyr、spyrBand 等函数
% 在独立入口（包括真实视频入口）中都能被 MATLAB 解析。
addpath(genpath(pyrRoot));
mexRoot = fullfile(pyrRoot, 'MEX');
if isfolder(mexRoot)
    addpath(mexRoot);
end
% fDSST 仅作为真实视频的可选动态 ROI 前置层；BPAF 的测量后端不依赖它。
trackerRoot = fullfile(cfg.projectRoot, 'third_party', 'fdsst_sunjiajian');
if isfolder(trackerRoot)
    addpath(trackerRoot);
end
addpath(fullfile(cfg.projectRoot, 'src'));
end
