function result=test_noise_lighting_blur(cfg)
% TEST_NOISE_LIGHTING_BLUR 检查 phase-only、幅值加权和结构支持在扰动下的可用性。
if nargin<1, cfg=default_config(pwd); end
rng(13,'twister'); h=80; w=100; base=rand(h,w); base=conv2(base,ones(5,5)/25,'same'); base=base/max(base(:));
perturbed=0.25+1.7*base+0.08*randn(h,w); perturbed=conv2(perturbed,ones(3,3)/9,'same'); perturbed=max(0,min(1,perturbed));
p0=build_complex_gabor_pyramid(base,cfg); p1=build_complex_gabor_pyramid(perturbed,cfg); phaseOnly=[]; weighted=[]; supported=[]; support0=compute_phase_congruency_support(p0); support1=compute_phase_congruency_support(p1);
for s=1:size(p0,1)
    for o=1:size(p0,2)
        phaseOnly(end+1)=phase_circular_similarity(p0(s,o).unitPhasor,p1(s,o).unitPhasor,ones(h,w)); %#ok<AGROW>
        ampWeight=2*p0(s,o).amplitude.*p1(s,o).amplitude./(p0(s,o).amplitude.^2+p1(s,o).amplitude.^2+eps);
        weighted(end+1)=phase_circular_similarity(p0(s,o).unitPhasor,p1(s,o).unitPhasor,ampWeight); %#ok<AGROW>
        supported(end+1)=phase_circular_similarity(p0(s,o).unitPhasor,p1(s,o).unitPhasor,double(support0&support1)); %#ok<AGROW>
    end
end
result=struct('phaseOnly',mean(phaseOnly),'amplitudeWeighted',mean(weighted),'phaseCongruencySupported',mean(supported),'passed',true);
end
