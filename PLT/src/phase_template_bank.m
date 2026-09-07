function bank = phase_template_bank(anchor,recent,best)
% PHASE_TEMPLATE_BANK 建立 V3 模板库。
% anchor 永不更新；recent 适应短期变化；best 保存历史最高质量模板。
if nargin<2, recent=[]; end
if nargin<3, best=[]; end
bank=struct('anchor',anchor,'recent',recent,'best',best,'anchorImmutable',true,...
    'recentQuality',-Inf,'bestQuality',-Inf,'recentFrame',1,'bestFrame',1,...
    'recentAge',Inf,'bestAge',Inf,'updateCount',0);
end
