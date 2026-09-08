function out=band_segments(x,fs,band)
% Missing values split runs. Never fill gaps or compress the time axis.
out=nan(size(x));[b,a]=butter(3,band/(fs/2),'bandpass');
edges=diff([false;isfinite(x(:));false]);starts=find(edges==1);ends=find(edges==-1)-1;
for k=1:numel(starts)
    ids=starts(k):ends(k);
    if numel(ids)>=max(32,ceil(3*fs/band(1))),out(ids)=filtfilt(b,a,x(ids));end
end
end
