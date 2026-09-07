function run_release()
% Fixed, documented configurations after exploratory ablations.
% These recordings were used during development: not a new blind dataset.
root=fileparts(mfilename('fullpath'));addpath(root);names={'motion13','motion27','random27','static13','static27','bridge'};
for i=1:numel(names)
    old=load(fullfile(root,'outputs','native_v1',names{i},'result.mat'),'cfg');c=old.cfg;
    c.maxSamples=6500;c.guideMode='geometry';c.referenceModel='translation';c.rois=c.rois([1 end],:);
    if strcmp(names{i},'random27'),c=old.cfg;c.maxSamples=1400;c.guideMode='median';end
    c.output=fullfile(root,'outputs','release',names{i});run_measurement(c);
end
evaluate_laser('release');test_contracts();run_synthetic_suite('synthetic_release',[42 137]);
end
