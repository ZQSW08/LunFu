function summary = main(varargin)
%MAIN TDDM MATLAB 论文复现总入口。
% 用法：summary = main();
% 真实数据存在时可传入：main('vibrationFolder', folder, ...)。

root = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(root, 'src')));
addpath(genpath(fullfile(root, 'config')));
addpath(genpath(fullfile(root, 'experiments')));
addpath(genpath(fullfile(root, 'tests')));
thirdParty = fullfile(root, 'third_party', 'matlabPyrTools');
if isfolder(thirdParty)
    addpath(thirdParty);
end
adic2d = fullfile(root, 'third_party', 'ADIC2D');
if isfolder(adic2d)
    addpath(adic2d);
end

cfg = paper_config();
opts = struct('vibrationFolder', '', 'rotationFolder', '', ...
    'runSynthetic', cfg.run.synthetic, 'runVibration', cfg.run.vibration, ...
    'runRotation', cfg.run.rotation, 'runAblation', cfg.run.ablation);
for k = 1:2:numel(varargin)
    if k + 1 > numel(varargin) || (~ischar(varargin{k}) && ~isstring(varargin{k}))
        error('Name-value arguments are required.');
    end
    name = char(varargin{k});
    if ~isfield(opts, name)
        error('Unknown option: %s', name);
    end
    opts.(name) = varargin{k + 1};
end

if ~isfolder(cfg.impl.outputRoot)
    mkdir(cfg.impl.outputRoot);
end

summary = struct();
summary.tests = run_all_tests(cfg);
if opts.runSynthetic
    summary.synthetic = run_synthetic_experiments(cfg);
end
if opts.runVibration
    summary.vibration = run_vibration_experiment(cfg, opts.vibrationFolder);
end
if opts.runRotation
    summary.rotation = run_rotation_experiment(cfg, opts.rotationFolder);
end
if opts.runAblation
    summary.ablation = run_ablation_experiments(cfg);
end

save(fullfile(cfg.impl.outputRoot, 'run_summary.mat'), 'summary', 'cfg');
disp('TDDM MATLAB reproduction completed.');
end
