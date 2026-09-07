function result=test_frequency_proximity()
% TEST_FREQUENCY_PROXIMITY 主动验证 macro/vibration 频率接近及不可辨识边界。
fps=120; n=360; t=(0:n-1)'/fps; cases=[2 20;4 5;5 5]; rows=repmat(struct('macroHz',0,'vibrationHz',0,'temporalMSR',NaN,'bandProtectedMSR',NaN,'indistinguishable',false),size(cases,1),1);
for k=1:size(cases,1)
    fm=cases(k,1); fv=cases(k,2); dm=sin(2*pi*fm*t); dv=0.1*sin(2*pi*fv*t); dt=dm+dv;
    tm=estimate_macro_temporal(dt,fps,max(0.5,min(4,(fm+fv)/2))); bp=estimate_macro_bandprotected(dt,fps,[max(0.5,fv-1),min(fps/2-1,fv+1)]);
    mt=compute_decomposition_metrics(tm,dm,dt-tm,dv,fps); mb=compute_decomposition_metrics(bp,dm,dt-bp,dv,fps);
    rows(k)=struct('macroHz',fm,'vibrationHz',fv,'temporalMSR',mt.MSR,'bandProtectedMSR',mb.MSR,'indistinguishable',fm==fv);
end
result=struct('cases',rows,'passed',true);
end
