function test_motion_separation
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
fs=100;t=(0:1999)'/fs;slow=10*sin(2*pi*.2*t);vib=.1*sin(2*pi*8*t);
tic;s=mfm.separate_motion(slow+vib,fs,1);seconds=toc;
mask=s.interior;rmse=sqrt(mean((s.vibration(mask)-vib(mask)).^2));
assert(rmse<.03,'Separated error unexpectedly high');
x=slow+vib;x(900:950)=NaN;g=mfm.separate_motion(x,fs,1);
assert(all(isnan(g.vibration(900:950))),'Gap was interpolated');
assert(~any(g.interior(850:1000)),'Gap boundary not excluded');
low=mfm.separate_motion(.1*sin(2*pi*.2*t),fs,1);
ratio=norm(low.vibration(mask))/norm(.1*sin(2*pi*.2*t(mask)));
assert(ratio<.1,'Low-frequency rejection failed');
high=mfm.separate_motion(slow+vib,fs,3,4);mask4=high.interior;
assert(sqrt(mean((high.vibration(mask4)-vib(mask4)).^2))<.01,'Fourth-order preservation failed');
assert(all(high.vibrationGain>=0&high.vibrationGain<=1),'Invalid transfer gain');
fprintf('motion separation: RMSE %.6g px, %.6g s, low-frequency gain %.6g\n',rmse,seconds,ratio);
end

