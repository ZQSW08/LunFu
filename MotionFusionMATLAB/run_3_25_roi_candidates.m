% Compare only first-frame target ROI choices; no reference/truth data is read.
close all; clearvars; clc; root=fileparts(mfilename('fullpath')); addpath(root);
rois={[1282 665 50 131],[1274 665 48 139],[1280 670 54 120]};
for i=1:numel(rois)
    u=mfm.real_defaults(); u.videoPath='D:\0819\3-25mvpp-motion.avi';
    u.outputRoot=fullfile(root,'outputs','roi_candidates_v4');u.captureFPS=100;
    u.axis='x';u.targetMode='profile';u.roiMode='manual';u.targetROI=rois{i};
    u.referenceROIs=zeros(0,4);u.referenceModel='none';u.autoProfileRows=true;
    u.analysisBandHz=[2 45];u.denoise=true;u.showFigures=false;u.exportFigures=false;
    fprintf('\nROI %d [%s]\n',i,num2str(rois{i})); run_real_video(u);
end
