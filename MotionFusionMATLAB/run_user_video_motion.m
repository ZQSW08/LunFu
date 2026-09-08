% Explicit example: slow motion below 3 Hz, vibration sufficiently above 3 Hz.
% Adjust cutoff from independent experimental knowledge, not desired peaks.
root=fileparts(mfilename('fullpath'));addpath(root);u=mfm.real_defaults();
u.videoPath='D:\07-26_single\man-qiao.avi';
u.outputRoot=fullfile(root,'outputs','motion_candidate_runs');
u.captureFPS=100;u.roiMode='interactive';
u.referenceModel='none';u.referenceROIs=[];u.targetMode='profile';
u.motionCutoffHz=3;u.motionOrder=4;
u.analysisBandHz=[];u.denoise=false;
u.exportTrackingVideo=true;u.showFigures=true;
result=run_real_video(u);
% 03_spectrum is RAW total motion for none and deliberately retains its peak.
% 05_motion_separation shows the candidate; consult motion_transfer_x.csv.
