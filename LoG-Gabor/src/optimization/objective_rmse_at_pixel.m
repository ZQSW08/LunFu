function rmse=objective_rmse_at_pixel(params,videoSpectrum,truth,cfg,pixel,theta0)
%OBJECTIVE_RMSE_AT_PIXEL 快速计算单像素 PME-RMSE。
% videoSpectrum 已预先完成二维 FFT；只计算目标像素的逆变换值，
% 与 pme_measure 的相位、展开和 PME 公式一致，避免生成整幅响应场。

[height,width,~]=size(videoSpectrum);
[filter,meta]=build_loggabor_filter(height,width,params,cfg,theta0);
[u,v]=meshgrid(0:width-1,0:height-1);
pixelKernel=exp(2*pi*1i*((pixel(1)-1)*v/height+(pixel(2)-1)*u/width));
pixelKernel=fftshift(pixelKernel);
weighted=videoSpectrum.*reshape(filter.*pixelKernel,height,width,1);
response=squeeze(sum(sum(weighted,1),2))/(height*width);
phase=unwrap(angle(response));
measured=[0; cumsum(-diff(phase)/meta.omega)];
truth=truth(:);
if numel(truth)~=numel(measured)
    error('objective_rmse_at_pixel:LengthMismatch','truth and measured displacement lengths differ.');
end
rmse=sqrt(mean((measured-truth).^2));
if ~isfinite(rmse), rmse=realmax; end
end
