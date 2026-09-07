function report = evaluate_object_motion_batch(resultRoot, outRoot)
%EVALUATE_OBJECT_MOTION_BATCH 评估四类具象物体视频的最终结果。
scriptPath = fileparts(mfilename('fullpath')); projectRoot = fileparts(scriptPath);
addpath(genpath(projectRoot));
if nargin < 1 || isempty(resultRoot), resultRoot = fullfile(projectRoot,'outputs','object_motion_results_final128'); end
if nargin < 2 || isempty(outRoot), outRoot = fullfile(projectRoot,'outputs','object_motion_evaluation_final128'); end
names = {'object_linear_clean','object_linear_light_blur','object_nonlinear_fast_rotation','object_nonlinear_all_conditions'};
dirs = cell(size(names));
for i=1:numel(names)
    d=dir(fullfile(resultRoot,[names{i} '_*'])); d=d([d.isdir]);
    if isempty(d), error('Crossline:MissingResult','缺少结果目录：%s',names{i}); end
    [~,ix]=max([d.datenum]); dirs{i}=fullfile(d(ix).folder,d(ix).name);
end
report=evaluate_motion_test_results(dirs,outRoot);
end
