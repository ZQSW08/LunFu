function run_refined_suite(tag)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
if nargin<1,tag='refined_v3';end
names={'motion27','random27','bridge'};
for i=1:numel(names)
    prev=load(fullfile(root,'outputs','native_v1',names{i},'result.mat'),'cfg');c=prev.cfg;
    c.maxSamples=6500;c.output=fullfile(root,'outputs',tag,names{i});run_measurement(c);
end
evaluate_laser(tag);
end



