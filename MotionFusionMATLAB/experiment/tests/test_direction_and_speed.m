function test_direction_and_speed()
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;out=fullfile(root,'outputs',['contracts_' datestr(now,'yyyymmdd_HHMMSS')]);mkdir(out);
source=fullfile(root,'outputs','synthetic_release','fast6_seed42.avi');truth=load(fullfile(root,'outputs','synthetic_release','fast6_seed42','truth.mat'),'rois');
v=VideoReader(source);dest=fullfile(out,'transposed.avi');w=VideoWriter(dest,'Motion JPEG AVI');w.Quality=100;w.FrameRate=v.FrameRate;open(w);
for k=1:60,im=readFrame(v);writeVideo(w,permute(im,[2 1 3]));end;close(w);
c=mfm.defaults();c.video=source;c.rois=truth.rois;c.radius=55;c.maxFrames=60;c.targetMode='texture';c.referenceModel='similarity';c.output=fullfile(out,'x');a=run_measurement(c);
c.video=dest;c.rois=truth.rois(:,[2 1 4 3]);c.axis='y';c.output=fullfile(out,'y');b=run_measurement(c);
good=a.geometryValid&b.geometryValid;error=sqrt(mean((a.relative(good,1)-b.relative(good,2)).^2));assert(error<.025,'Direction coordinate mismatch');
c.video=source;c.rois=truth.rois;c.axis='x';c.fastSearch=true;c.output=fullfile(out,'fast');f=run_measurement(c);
good=a.geometryValid&f.geometryValid;delta=sqrt(mean((a.relative(good,1)-f.relative(good,1)).^2));assert(delta<.01,'Fast search changed metrology');
save(fullfile(out,'checks.mat'),'error','delta');fprintf('PASS y transpose RMSE %.5f px; fast/standard difference %.5f px.\n',error,delta);
end


