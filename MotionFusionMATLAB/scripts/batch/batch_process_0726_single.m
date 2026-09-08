%% Batch processing: 07-26_single videos
% Comment individual entries in videoFiles to control which videos run.
close all; clearvars; clc;
scriptRoot=fileparts(mfilename('fullpath')); projectRoot=fileparts(fileparts(scriptRoot)); addpath(fullfile(projectRoot,'src'));
videoFiles={ ...
    'D:\07-26_single\kuai-buqiao.avi', ...
    'D:\07-26_single\kuai-qiao.avi', ...
    'D:\07-26_single\luandong-buqiao.avi', ...
    'D:\07-26_single\luandong-qiao.avi', ...
    'D:\07-26_single\man-buqiao.avi', ...
    'D:\07-26_single\man-qiao.avi', ...
    'D:\07-26_single\static-qiao.avi' ...
};
outputRoot=fullfile(projectRoot,'outputs','batch_0726_single');
for k=1:numel(videoFiles)
    videoPath=videoFiles{k};
    if ~isfile(videoPath), warning('Skipping missing video: %s',videoPath); continue; end
    [~,name]=fileparts(videoPath); fprintf('\n=== [%d/%d] %s ===\n',k,numel(videoFiles),name);
    u=mfm.real_defaults(); u.videoPath=videoPath; u.outputRoot=outputRoot;
    u.captureFPS=[]; u.maxFrames=Inf; u.axis='x';
    u.roiMode='interactive'; u.targetROI=[]; u.roiSource='';
    u.referenceModel='translation'; u.referenceSelection='interactive'; u.referenceROIs=[];
    u.targetMode='direct'; u.referenceTracker='flow'; u.autoProfileRows=true; u.maxSamples=6500;
    u.analysisBandHz=[]; u.denoise=false; u.showFigures=true; u.exportFigures=true; u.exportTrackingVideo=false;
    run_real_video(u);
end
fprintf('\n07-26_single batch finished.\n');
