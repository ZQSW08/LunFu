function run_spatial_pilot(tag,refTracker,targetMode,model)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
if nargin<1,tag='spatial_pilot1';end
if nargin<2,refTracker='tiles';end
if nargin<3,targetMode='consensus';end
if nargin<4,model='translation';end
for name={'kuai-qiao','3-25mvpp-motion'}
    s=load(fullfile(root,'outputs','manual_v4',name{1},'result.mat'),'cfg');
    c=s.cfg;c.maxSamples=6500;c.guideMode='geometry';c.axis='x';
    c.targetMode=targetMode;c.referenceTracker=refTracker;
    c.referenceModel=model;
    c.output=fullfile(root,'outputs',tag,name{1});
    run_measurement(c);
end
end



