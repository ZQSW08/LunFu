%PROCESS_PAPER_SV_VIDEOS 处理论文规格 SV1/SV2 并导出测量区域与结果图。

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot, 'src'));
cfg = bpaf.default_config();
opts = struct('spatialScale', 0.5, 'temporalStride', 4, 'tag', 'fast');
results = bpaf.process_paper_sv_videos(cfg, {'SV1', 'SV2'}, opts); %#ok<NASGU>
disp('快速处理完成，结果位于 outputs/data/paper_sv_fast 和 outputs/figures/paper_sv_processed_fast。');
