close all;clearvars;clc;scriptroot=projectRoot;projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
for ax={'x','y'}
 u=mfm.real_defaults();u.videoPath='D:\0819\3-25mvpp-motion.avi';u.outputRoot=fullfile(root,'outputs','direction_v4');u.captureFPS=100;u.maxFrames=Inf;u.axis=ax{1};u.targetMode='profile';u.roiMode='manual';u.targetROI=[1282 665 50 131];u.referenceROIs=zeros(0,4);u.referenceModel='none';u.autoProfileRows=true;u.analysisBandHz=[2 45];u.denoise=true;u.showFigures=false;u.exportFigures=false;fprintf('\n=== %s ===\n',ax{1});run_real_video(u);
end



