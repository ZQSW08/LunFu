function result = frequency_ods(displacement, fs, targetFrequency, bandwidth)
%FREQUENCY_ODS 提取给定频带的 amplitude map 与相对相位 ODS。
% 论文将频率 ODS 的振幅作为带通时间信号的 mean absolute displacement；
% 这不是严格意义上的单频峰值，因此代码名称和输出字段均显式区分。
[height,width,frames]=size(displacement);
freq=(0:frames-1)*fs/frames; positive=1:floor(frames/2)+1;
fftField=fft(displacement,[],3);
band=abs(freq-targetFrequency)<=bandwidth;
band(positive(end)+1:end)=false;
filtered=zeros(size(fftField));
filtered(:,:,band)=fftField(:,:,band);
% 对保留频带补入共轭负频率，使时域结果为实数。
for k=2:floor(frames/2)
    mirror=frames-k+2;
    if band(k), filtered(:,:,mirror)=fftField(:,:,mirror); end
end
bandSignal=real(ifft(filtered,[],3));
amplitude=mean(abs(bandSignal),3);
positiveBins=positive(abs(freq(positive)-targetFrequency)<=bandwidth);
if isempty(positiveBins), positiveBins=positive(1); end
[~,pick]=max(abs(fftField(:,:,positiveBins)),[],3);
phase=zeros(height,width);
for i=1:height
    for j=1:width
        phase(i,j)=angle(fftField(i,j,positiveBins(pick(i,j))));
    end
end
reference=phase(ceil(height/2),ceil(width/2));
result.amplitude=amplitude;
result.phase=angle(exp(1i*(phase-reference)));
result.bandSignal=bandSignal;
result.frequencyAxis=freq;
result.targetFrequency=targetFrequency;
result.bandwidth=bandwidth;
end
