function pyramid = build_complex_gabor_pyramid(grayFrame, cfg)
% BUILD_COMPLEX_GABOR_PYRAMID 计算多尺度、多方向复 Gabor 响应。
% 对每个通道保存 amplitude、wrapped phase、unit phasor 和可靠性权重。
% 复滤波器对应参考论文 Eq. (1) 的 Gaussian envelope * complex sinusoid；
% 这里方向和波长是面向自然纹理跟踪的实现配置，而不是 crossline 专用参数。

grayFrame = to_gray_double(grayFrame);
[height, width] = size(grayFrame);
numScales = numel(cfg.method.wavelengthsPx);
numOrientations = numel(cfg.method.orientationsDeg);
persistent filterCache filterCacheKey
newCacheKey = sprintf('%d_%d|wl=%s|or=%s|sa=%.8g|sc=%.8g|sr=%.8g', ...
    height, width, mat2str(cfg.method.wavelengthsPx), mat2str(cfg.method.orientationsDeg), ...
    cfg.method.gabor.sigmaAlongRatio, cfg.method.gabor.sigmaAcrossRatio, cfg.method.gabor.supportSigma);
if isempty(filterCache) || ~strcmp(filterCacheKey, newCacheKey)
    filterCache = repmat(struct('wavelength', [], 'orientationDeg', [], ...
        'kernel', [], 'spectrum', []), numScales, numOrientations);
    for s = 1:numScales
        for o = 1:numOrientations
            wavelength = cfg.method.wavelengthsPx(s);
            angleDeg = cfg.method.orientationsDeg(o);
            kernel = make_complex_gabor(wavelength, angleDeg, cfg.method.gabor);
            kernelPadded = zeros(height, width);
            kernelPadded(1:size(kernel,1), 1:size(kernel,2)) = rot90(kernel,2);
            kernelPadded = circshift(kernelPadded, -floor([size(kernel,1), size(kernel,2)]/2));
            filterCache(s,o).wavelength = wavelength;
            filterCache(s,o).orientationDeg = angleDeg;
            filterCache(s,o).kernel = kernel;
            filterCache(s,o).spectrum = fft2(kernelPadded);
        end
    end
    filterCacheKey = newCacheKey;
end
imageSpectrum = fft2(grayFrame);
pyramid = repmat(struct('wavelength', [], 'orientationDeg', [], ...
    'response', [], 'amplitude', [], 'phase', [], 'unitPhasor', [], ...
    'reliability', [], 'wavevector', []), numScales, numOrientations);

for s = 1:numScales
    wavelength = cfg.method.wavelengthsPx(s);
    for o = 1:numOrientations
        angleDeg = cfg.method.orientationsDeg(o);
        kernel = filterCache(s,o).kernel;
        response = apply_complex_filter(grayFrame, imageSpectrum, filterCache(s,o).spectrum);
        amplitude = abs(response);
        phase = angle(response);
        unitPhasor = response ./ max(amplitude, eps);
        reliability = compute_phase_reliability(amplitude, cfg.method.minAmplitudeFraction);
        pyramid(s,o).wavelength = wavelength;
        pyramid(s,o).orientationDeg = angleDeg;
        pyramid(s,o).response = response;
        pyramid(s,o).amplitude = amplitude;
        pyramid(s,o).phase = phase;
        pyramid(s,o).unitPhasor = unitPhasor;
        pyramid(s,o).reliability = reliability;
        % 复 Gabor 的相位对平移的线性近似；卷积约定使此处带负号。
        theta = deg2rad(angleDeg);
        pyramid(s,o).wavevector = -(2*pi/wavelength) * [cos(theta), sin(theta)];
    end
end

if height < 1 || width < 1
    error('输入帧为空。');
end
end

function img = to_gray_double(frame)
frame = double(frame);
if ndims(frame) == 3
    img = 0.298936*frame(:,:,1) + 0.587043*frame(:,:,2) + 0.114021*frame(:,:,3);
else
    img = frame;
end
if max(img(:)) > 1
    img = img / 255;
end
img(~isfinite(img)) = 0;
end

function kernel = make_complex_gabor(wavelength, angleDeg, gaborCfg)
sigmaAlong = gaborCfg.sigmaAlongRatio * wavelength;
sigmaAcross = gaborCfg.sigmaAcrossRatio * wavelength;
halfSize = ceil(gaborCfg.supportSigma * max(sigmaAlong, sigmaAcross));
[x, y] = meshgrid(-halfSize:halfSize, -halfSize:halfSize);
theta = deg2rad(angleDeg);
u = x*cos(theta) + y*sin(theta);
v = -x*sin(theta) + y*cos(theta);
envelope = exp(-(u.^2/(2*sigmaAlong^2) + v.^2/(2*sigmaAcross^2)));
carrier = exp(1i*2*pi*(x*cos(theta) + y*sin(theta))/wavelength);
kernel = envelope .* carrier;
% 去除 DC，减少光照偏置对相位的污染，同时保留复滤波器方向性。
kernel = kernel - mean(kernel(:));
kernel = kernel / max(sum(abs(kernel(:))), eps);
end

function response = apply_complex_filter(img, imageSpectrum, kernelSpectrum)
% 频域卷积显著降低大波长 Gabor 的逐像素卷积开销；边界采用循环延拓，
% ROI 选择时应尽量避开图像边缘。相位通道的中心区域不受该边界策略影响。
[height,width]=size(img); [fftHeight,fftWidth]=size(kernelSpectrum);
if height~=fftHeight || width~=fftWidth
    imageSpectrum=fft2(img,fftHeight,fftWidth);
end
response=ifft2(imageSpectrum.*kernelSpectrum);
response=response(1:height,1:width);
response=real(response)+1i*imag(response);
end
