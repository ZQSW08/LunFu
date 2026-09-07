function run_stable_suite(tag)
% A fixed one-reference translation model; retains rotation limitation.
if nargin<1,tag='stable_v2';end
root=fileparts(mfilename('fullpath'));addpath(root);
names={'motion13','motion27','random27','static13','static27','bridge'};
for i=1:numel(names)
    prev=load(fullfile(root,'outputs','native_v1',names{i},'result.mat'),'cfg');c=prev.cfg;
    c.rois=c.rois([1 end],:);c.referenceModel='translation';c.maxSamples=6500;
    c.output=fullfile(root,'outputs',tag,names{i});run_measurement(c);
end
evaluate_laser(tag);
end
