function result = measurement_consistency(trackSignal, phaseSignal, trackQuality, phaseQuality, options)
%MEASUREMENT_CONSISTENCY 跟踪—相位互证；输出质量修正和弱跟踪辅助预测。
if nargin<5, options=struct(); end
defaults=struct('window',9,'maximumNormalizedMismatch',3,'assistGain',0.35);
options=rmptf.merge_config(defaults,options);
trackSignal=double(trackSignal(:)); phaseSignal=double(phaseSignal(:));
n=min(numel(trackSignal),numel(phaseSignal)); trackSignal=trackSignal(1:n); phaseSignal=phaseSignal(1:n);
trackQuality=localVector(trackQuality,n,1); phaseQuality=localVector(phaseQuality,n,1);
dt=[0;diff(trackSignal)]; dp=[0;diff(phaseSignal)]; mismatch=abs(dt-dp);
scale=movmedian(abs(dp-movmedian(dp,options.window,'omitnan')),options.window,'omitnan');
normalizedMismatch=mismatch./max(1e-6,1.4826*scale);
agreement=exp(-normalizedMismatch/max(options.maximumNormalizedMismatch,eps));
fusedQuality=min(1,max(0,sqrt(max(trackQuality,0).*max(phaseQuality,0)).*agreement));
assistMask=trackQuality<0.5 & phaseQuality>=0.65 & agreement>=0.45;
assisted=trackSignal;
assisted(assistMask)=trackSignal(assistMask)+options.assistGain*(dp(assistMask)-dt(assistMask));
result=struct('agreement',agreement,'normalizedMismatch',normalizedMismatch, ...
    'fusedQuality',fusedQuality,'phaseAssistUsed',assistMask,'assistedPrediction',assisted);
end

function value=localVector(value,n,defaultValue)
if nargin<3, defaultValue=1; end
if isempty(value), value=defaultValue*ones(n,1); else, value=double(value(:)); value=value(1:min(n,end)); end
if numel(value)<n, value(end+1:n,1)=value(end); end
value(~isfinite(value))=0;
end
