function run_upgrade_suite(tag)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
if nargin<1,tag='real_v2';end
videos={'C:/0819/2-5mvpp-motion.avi','C:/0819/4-25mvpp-motion.avi','C:/0819/4-25mvpp-luandong.avi','C:/0819/2-5mvpp-static.avi','C:/0819/4-25mvpp-static.avi','D:/07-26_single/man-qiao.avi'};
test_upgrade();
for j=1:numel(videos)
    u=mfm.real_defaults();u.videoPath=videos{j};u.outputRoot=fullfile(root,'outputs',tag);u.captureFPS=100;u.showFigures=false;run_real_video(u);
end
end



