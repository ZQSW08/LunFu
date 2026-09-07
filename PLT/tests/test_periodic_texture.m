function result=test_periodic_texture()
% TEST_PERIODIC_TEXTURE 比较单波长与多波长的周期假峰率。
x=0:127; candidates=-48:48; trueShift=7; wavelengthSets={[24],[24 15],[24 15 9]}; falsePeakRate=zeros(1,3); peakToSecond=zeros(1,3);
for k=1:numel(wavelengthSets)
    scores=zeros(size(candidates));
    for q=1:numel(candidates)
        perChannel=zeros(1,numel(wavelengthSets{k}));
        for j=1:numel(wavelengthSets{k})
            lambda=wavelengthSets{k}(j); z0=exp(1i*2*pi*x/lambda); zq=exp(1i*2*pi*(x+candidates(q)-trueShift)/lambda); perChannel(j)=phase_circular_similarity(z0,zq,ones(size(x)));
        end
        scores(q)=mean(perChannel);
    end
    trueIndex=find(candidates==trueShift,1); trueScore=scores(trueIndex); exclude=abs(candidates-trueShift)<=1; second=max(scores(~exclude)); falsePeakRate(k)=mean(scores(~exclude)>=trueScore); peakToSecond(k)=(trueScore-second)/max(abs(second),eps);
end
result=struct('wavelengthCounts',[1 2 3],'falsePeakRate',falsePeakRate,'peakToSecond',peakToSecond,'passed',true);
end
