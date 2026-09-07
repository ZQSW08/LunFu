function test_upgrade()
root=fileparts(mfilename('fullpath'));addpath(root);rng(3091);fs=100;t=(0:1199)'/fs;
z=.2*sin(2*pi*11.3*t)+.13*sin(2*pi*23.7*t);x=z+.04*randn(size(t));s=mfm.clean_signal(x,fs,[2 45],true);
assert(numel(s.modesHz)>=2&&min(abs(s.modesHz-11.3))<.6&&min(abs(s.modesHz-23.7))<.6,'Lost a true mode');
ids=100:1100;before=sqrt(mean((s.broad(ids)-z(ids)).^2));after=sqrt(mean((s.clean(ids)-z(ids)).^2));assert(after<before,'No denoising gain');
noise=mfm.clean_signal(.04*randn(size(t)),fs,[2 45],true);assert(isempty(noise.modesHz),'Noise fabricated a stable mode');
x(540:560)=NaN;s=mfm.clean_signal(x,fs,[2 45],true);assert(all(isnan(s.clean(540:560))),'Gap interpolated');
u=mfm.real_defaults();u.referenceModel='none';u.videoPath='C:/0819/2-5mvpp-motion.avi';v=VideoReader(u.videoPath);im=readFrame(v);[roi,~,p]=mfm.resolve_rois(u,im);saved=load(p.targetSource,'roi');assert(isequal(roi,double(saved.roi(:)')),'Saved ROI changed');
% Algorithm APIs cannot receive a reference laser signal or expected frequency.
assert(~isfield(u,'laserPath')&&~isfield(u,'expectedFrequencyHz'));
test_contracts();fprintf('UPGRADE PASS: two non-integer modes retained; noise rejected; gap preserved; exact saved ROI. RMSE %.5f -> %.5f px\n',before,after);
end
