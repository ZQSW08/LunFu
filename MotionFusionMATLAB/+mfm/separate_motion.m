function out=separate_motion(x,fs,cutoff,order)
% Explicit smooth-motion prior; missing frames divide independent segments.
if nargin<4,order=2;end
assert(isscalar(order)&&any(order==[2 4]),'Motion order must be 2 or 4');
x=x(:);assert(isscalar(fs)&&isfinite(fs)&&fs>0,'Invalid sample rate');
assert(isscalar(cutoff)&&isfinite(cutoff)&&cutoff>0&&cutoff<fs/2,'Invalid motion cutoff');
lambda=1/(2*sin(pi*cutoff/fs))^(2*order);
out=struct('trend',nan(size(x)),'vibration',nan(size(x)),...
    'interior',false(size(x)),'cutoffHz',cutoff,'lambda',lambda,'order',order,...
    'assumption','Smooth macromotion; overlapping vibration may be removed');
edges=diff([false;isfinite(x);false]);a=find(edges==1);b=find(edges==-1)-1;
margin=ceil(fs/cutoff);
for j=1:numel(a)
    ids=a(j):b(j);n=numel(ids);if n<max(16,2*margin+1),continue;end
    coefficients=arrayfun(@(k)(-1)^k*nchoosek(order,k),0:order);
    row=repmat((1:n-order)',1,order+1);col=(1:n-order)'+(0:order);
    val=repmat(coefficients,n-order,1);D=sparse(row(:),col(:),val(:),n-order,n);
    trend=(speye(n)+lambda*(D'*D))\x(ids);
    out.trend(ids)=trend;out.vibration(ids)=x(ids)-trend;
    out.interior(ids(margin+1:end-margin))=true;
end
out.frequency=(0:512)'*fs/1024;
q=lambda*(2*sin(pi*out.frequency/fs)).^(2*order);
out.vibrationGain=q./(1+q);
end
