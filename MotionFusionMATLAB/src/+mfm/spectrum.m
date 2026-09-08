function s=spectrum(x,fs)
% Longest CONTIGUOUS run, physical single-sided Hann amplitude. No gap filling.
e=diff([false;isfinite(x(:));false]);a=find(e==1);b=find(e==-1)-1;
s=struct('frequency',[],'amplitude',[],'startFrame',NaN,'samples',0,'resolutionHz',NaN);
if isempty(a),return;end
[n,k]=max(b-a+1);if n<16,return;end
z=detrend(x(a(k):b(k)));w=hann(n);v=abs(fft(z.*w))*2/sum(w);v(1)=v(1)/2;
if mod(n,2)==0,v(n/2+1)=v(n/2+1)/2;end
s.frequency=(0:floor(n/2))'*fs/n;s.amplitude=v(1:floor(n/2)+1);s.startFrame=a(k);s.samples=n;s.resolutionHz=fs/n;
end
