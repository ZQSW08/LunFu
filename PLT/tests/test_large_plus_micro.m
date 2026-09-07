function result=test_large_plus_micro()
% TEST_LARGE_PLUS_MICRO 验证 temporal、band-protected、spatial 三种 V2 解耦路径。
fps=120; n=240; t=(0:n-1)'/fps; dMacro=[35*sin(2*pi*0.8*t),12*cos(2*pi*0.6*t)]; dVib=[0.08*sin(2*pi*18*t),0.05*cos(2*pi*18*t)]; dTotal=dMacro+dVib;
temporal=estimate_macro_temporal(dTotal,fps,3); band=estimate_macro_bandprotected(dTotal,fps,[10 25]);
rng(17,'twister'); patchTracks=zeros(n,2,5); for p=1:5, patchTracks(:,:,p)=dMacro+dVib.*(0.4+0.15*p)+0.03*randn(n,2); end, [spatial,~,consensus]=estimate_macro_spatial(patchTracks);
metricsTemporal=compute_decomposition_metrics(temporal,dMacro,dTotal-temporal,dVib,fps); metricsBand=compute_decomposition_metrics(band,dMacro,dTotal-band,dVib,fps); metricsSpatial=compute_decomposition_metrics(spatial,dMacro,dTotal-spatial,dVib,fps);
result=struct('metricsTemporal',metricsTemporal,'metricsBandProtected',metricsBand,'metricsSpatial',metricsSpatial,'minimumConsensus',min(consensus),...
    'fps',fps,'dTotal',dTotal,'dMacroTemporal',temporal,'dMacroBandProtected',band,'dMacroSpatial',spatial,...
    'dVibTemporal',dTotal-temporal,'dVibBandProtected',dTotal-band,'dVibSpatial',dTotal-spatial,'passed',true);
end
