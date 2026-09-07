function out=clean_signal(x,fs,band,enabled)
% Video-only modal extraction: stable spectral evidence in >=2 time blocks.
% Outputs BOTH broad measured component and explicitly model-filtered component.
if isempty(band)
    assert(~enabled,'Set an explicit analysisBandHz before requesting legacy modal filtering');
    out=struct('raw',x,'broad',x,'clean',x,'modesHz',[],'bandsHz',[],...
        'status','unfiltered_measurement','retainedPowerFraction',NaN,'removedRMS',0,'bandHz',[]);
    return;
end
band(2)=min(band(2),.45*fs);assert(band(1)>0&&band(2)>band(1),'Invalid analysis band');
raw=mfm.band_segments(x,fs,band);clean=raw;
out=struct('raw',x,'broad',raw,'clean',clean,'modesHz',[],'bandsHz',[],...
    'status','disabled','retainedPowerFraction',NaN,'removedRMS',0,'bandHz',band);
if ~enabled,return;end
% Two-second blocks. Estimate frequency from observations, not filename or truth.
L=round(2*fs);hop=floor(L/2);powers=[];blocks=[];starts=[];nfft=4*2^nextpow2(L);f=(0:nfft/2)'*fs/nfft;
for start=1:hop:numel(x)-L+1
    z=x(start:start+L-1);valid=isfinite(z);if mean(valid)<.85,continue;end
    % Weighted Fourier sum over observed timestamps. Missing samples have
    % ZERO WEIGHT, not invented zero displacement; output gaps stay NaN.
    design=[ones(L,1) (0:L-1)'/fs];beta=design(valid,:)\z(valid);weighted=zeros(L,1);
    win=hann(L);weighted(valid)=(z(valid)-design(valid,:)*beta).*win(valid);
    p=abs(fft(weighted,nfft)).^2;p=p(1:nfft/2+1);p(f<band(1)|f>band(2))=0;
    noise=median(p(f>=band(1)&f<=band(2)));powers(:,end+1)=p/max(noise,eps);blocks(:,end+1)=weighted;starts(end+1)=start; %#ok<AGROW>
end
out.evidenceWindows=size(powers,2);out.missingSpectralSamples='zero weight at original timestamps; no waveform interpolation';
if size(powers,2)<4,out.status='insufficient_time_window_evidence';return;end
aggregate=median(powers,2);[peaks,ids]=findpeaks(aggregate,'MinPeakDistance',max(1,round(1/(fs/nfft)))) ;
good=peaks>=12 & mean(powers(ids,:)>=8,2)>=.6;ids=ids(good);peaks=peaks(good);
if isempty(ids),out.status='no_stable_modes';return;end
keep=peaks>=.03*max(peaks);ids=ids(keep);peaks=peaks(keep);
if numel(ids)>4,out.status='broadband_or_many_modes_no_narrowing';return;end
% A broad transient can pass a power-only test. Require phase consistency
% across time blocks for the specifically periodic/modal output.
centers=f(ids);coherence=zeros(size(centers));
for j=1:numel(centers)
    scan=centers(j)+linspace(-.25,.25,31);scan=scan(scan>=band(1)&scan<=band(2));
    coefficients=exp(-2i*pi*scan(:)*(0:L-1)/fs)*blocks;
    coefficients=coefficients.*exp(-2i*pi*scan(:)*(starts-1)/fs);
    consistency=abs(mean(coefficients./max(abs(coefficients),eps),2));[coherence(j),ix]=max(consistency);centers(j)=scan(ix);
end
out.candidateHz=centers;out.phaseCoherence=coherence;centers=centers(coherence>=.75);
if isempty(centers),out.status='no_phase_coherent_modes_broad_preserved';return;end
width=max(1.25,2*fs/L);bands=[max(band(1),centers-width) min(band(2),centers+width)];bands=sortrows(bands);
merged=bands(1,:);for k=2:size(bands,1),if bands(k,1)<=merged(end,2),merged(end,2)=max(merged(end,2),bands(k,2));else,merged(end+1,:)=bands(k,:);end;end
clean=nan(size(x));e=diff([false;isfinite(raw);false]);a=find(e==1);b=find(e==-1)-1;
for k=1:numel(a)
    ix=a(k):b(k);if numel(ix)<max(32,ceil(3*fs/min(merged(:,1)))),continue;end
    y=zeros(numel(ix),1);
    for j=1:size(merged,1)
        [bb,aa]=butter(3,merged(j,:)/(fs/2),'bandpass');y=y+filtfilt(bb,aa,raw(ix));
    end
    clean(ix)=y;
end
out.clean=clean;out.modesHz=centers;out.bandsHz=merged;out.status='video_identified_modal_component';
ok=isfinite(clean)&isfinite(raw);out.retainedPowerFraction=sum(clean(ok).^2)/max(eps,sum(raw(ok).^2));out.removedRMS=sqrt(mean((raw(ok)-clean(ok)).^2));
end
