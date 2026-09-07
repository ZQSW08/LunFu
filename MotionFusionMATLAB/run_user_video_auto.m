function result=run_user_video_auto(videoPath,outputRoot,targetROI,searchROI,overrides)
% Automatic multi-patch reference entry point. searchROI is optional but must
% mostly cover the same macroscopic moving body as the target.
if nargin<4,searchROI=[];end;if nargin<5,overrides=struct();end
u=mfm.real_defaults();u.videoPath=videoPath;u.outputRoot=outputRoot;u.roiMode='manual';u.targetROI=targetROI;
u.referenceROIs=[];u.referenceSelection='automatic';u.referenceModel='translation';u.referenceTracker='anchor';u.searchROI=searchROI;
names=fieldnames(overrides);for j=1:numel(names),assert(isfield(u,names{j}),'Unknown public option');u.(names{j})=overrides.(names{j});end
result=run_real_video(u);
end
