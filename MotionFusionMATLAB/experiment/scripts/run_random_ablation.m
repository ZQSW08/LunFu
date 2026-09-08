function run_random_ablation()
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
r=load(fullfile(root,'outputs','native_v1','random27','result.mat'),'cfg');c=r.cfg;c.maxSamples=1400;c.guideMode='median';c.output=fullfile(root,'outputs','sparse_median_v5','random27');run_measurement(c);evaluate_laser('sparse_median_v5');
end



