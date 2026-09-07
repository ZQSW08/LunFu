function [score,coherence,meanPhase] = phase_circular_similarity(templateZ,currentZ,weights)
% PHASE_CIRCULAR_SIMILARITY 计算 unit phasor 的 circular phase 相似度。
% 复数 resultant 同时给出余弦匹配、相位集中度和平均相位偏差。
if nargin<3 || isempty(weights), weights=ones(size(templateZ)); end
resultant=sum(weights(:).*exp(1i*angle(conj(templateZ(:)).*currentZ(:)))); totalWeight=sum(weights(:));
if totalWeight<=eps, score=-1; coherence=0; meanPhase=NaN; return; end
coherence=abs(resultant)/totalWeight; meanPhase=angle(resultant); score=real(resultant)/totalWeight;
end
