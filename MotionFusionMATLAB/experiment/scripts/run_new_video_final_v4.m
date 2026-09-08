% Final reproducible examples for the two previously failing videos.
% The algorithm receives only the video and first-frame target ROI.
close all; clearvars; clc; scriptroot=projectRoot;projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
cases={
 struct('video','D:\07-26_single\kuai-qiao.avi','name','kuai-qiao','roi',[1165 328 66 92],'axis','x'), ...
 struct('video','D:\0819\3-25mvpp-motion.avi','name','3-25mvpp-motion','roi',[1282 665 50 131],'axis','y')};
outRoot=fullfile(root,'outputs','target_only_final_v4');
for i=1:numel(cases)
 u=mfm.real_defaults(); u.videoPath=cases{i}.video; u.outputRoot=outRoot;
 u.captureFPS=100; u.maxFrames=Inf; u.axis=cases{i}.axis; u.targetMode='profile';
 u.roiMode='manual'; u.targetROI=cases{i}.roi; u.referenceROIs=zeros(0,4);
 u.referenceModel='none'; u.autoProfileRows=true; u.analysisBandHz=[2 45];
 u.denoise=true; u.showFigures=false; u.exportFigures=true;
 fprintf('\n=== %s (%s target-only) ===\n',cases{i}.name,cases{i}.axis); run_real_video(u);
end



