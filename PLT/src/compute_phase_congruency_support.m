function support = compute_phase_congruency_support(pyramid)
% COMPUTE_PHASE_CONGRUENCY_SUPPORT 用跨尺度相位集中度构造结构支持掩码。
% 该支持仅用于 reliability，不替代位移相位。
[ns,no]=size(pyramid); [h,w]=size(pyramid(1,1).phase); resultant=zeros(h,w); weightSum=zeros(h,w);
for s=1:ns
    for o=1:no
        z=pyramid(s,o).unitPhasor; weight=double(pyramid(s,o).reliability).*pyramid(s,o).amplitude;
        resultant=resultant+weight.*z; weightSum=weightSum+weight;
    end
end
coherence=abs(resultant)./max(weightSum,eps); support=coherence>=0.35 & weightSum>0;
end
