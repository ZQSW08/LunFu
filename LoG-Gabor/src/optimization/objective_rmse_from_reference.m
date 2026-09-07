function rmse=objective_rmse_from_reference(params,referenceSpectrum,displacementXY,cfg,pixel,theta0)
%OBJECTIVE_RMSE_FROM_REFERENCE 用真实首帧的频谱快速计算训练 RMSE。
% 训练视频来自“首帧 + 已知 Fourier 平移”，因此不必保存所有训练帧的
% 三维 FFT；逐帧计算目标像素响应即可，避免高分辨率视频占满内存。

[height,width]=size(referenceSpectrum);
[filter,meta]=build_loggabor_filter(height,width,params,cfg,theta0);
[fx,fy]=centered_frequency_grid(height,width);
[u,v]=meshgrid(0:width-1,0:height-1);
pixelKernel=exp(2*pi*1i*((pixel(1)-1)*v/height+(pixel(2)-1)*u/width));
pixelKernel=fftshift(pixelKernel);
baseWeight=referenceSpectrum.*filter.*pixelKernel;
frames=size(displacementXY,1); response=zeros(frames,1);
for k=1:frames
    shiftFactor=exp(-2*pi*1i*(fx*displacementXY(k,1)+fy*displacementXY(k,2)));
    response(k)=sum(baseWeight.*shiftFactor,'all')/(height*width);
end
phase=unwrap(angle(response)); measured=[0; cumsum(-diff(phase)/meta.omega)];
truth=displacementXY(:,1)*cos(theta0)+displacementXY(:,2)*sin(theta0);
rmse=sqrt(mean((measured-truth).^2));
if ~isfinite(rmse), rmse=realmax; end
end

function [fx,fy]=centered_frequency_grid(height,width)
fxv=(-floor(width/2):ceil(width/2)-1)/width;
fyv=(-floor(height/2):ceil(height/2)-1)/height;
[fx,fy]=meshgrid(fxv,fyv);
end
