% Reproducible diagnostic for videos whose target is not rigidly tied to a
% visible reference.  It deliberately does not read laser/truth data.
close all; clearvars; clc;
root=fileparts(mfilename('fullpath')); addpath(root);
cases={
    struct('video','D:\07-26_single\kuai-qiao.avi','roi',[1165 328 66 92],'name','kuai-qiao'), ...
    struct('video','D:\0819\3-25mvpp-motion.avi','roi',[1282 665 50 131],'name','3-25mvpp-motion')};
outRoot=fullfile(root,'outputs','target_only_v4');
for i=1:numel(cases)
    u=mfm.real_defaults();
    u.videoPath=cases{i}.video; u.outputRoot=outRoot;
    u.captureFPS=100; u.maxFrames=Inf; u.axis='x';
    u.targetMode='profile'; u.roiMode='manual'; u.targetROI=cases{i}.roi;
    u.referenceROIs=zeros(0,4); u.referenceModel='none';
    u.autoProfileRows=true; u.analysisBandHz=[2 45]; u.denoise=true;
    u.showFigures=false; u.exportFigures=true;
    fprintf('\n=== %s: target-only profile vertical-search ===\n',cases{i}.name);
    run_real_video(u);
end
