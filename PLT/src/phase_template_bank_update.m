function [bank,updated,source] = phase_template_bank_update(bank,candidate,quality,frameIndex,cfg)
% PHASE_TEMPLATE_BANK_UPDATE 仅用高质量帧更新 recent/best 模板。
% 更新的是跟踪模板；anchor 仍保持首帧不变，保证测量坐标不漂移。
updated=false; source='none';
if ~isfield(bank,'recentFrame'), bank.recentFrame=1; end
if ~isfield(bank,'bestFrame'), bank.bestFrame=1; end
if ~isfield(bank,'recentQuality'), bank.recentQuality=-Inf; end
if ~isfield(bank,'bestQuality'), bank.bestQuality=-Inf; end
if ~isfield(bank,'updateCount'), bank.updateCount=0; end
bank.recentAge=frameIndex-bank.recentFrame; bank.bestAge=frameIndex-bank.bestFrame;
if ~isfield(cfg.method,'templateBankEnabled') || ~cfg.method.templateBankEnabled, return; end
if ~isfinite(quality) || quality<cfg.method.templateUpdateMinQuality || isempty(candidate), return; end
if isempty(bank.recent) || frameIndex-bank.recentFrame>=cfg.method.templateUpdateIntervalFrames
    bank.recent=candidate; bank.recentQuality=quality; bank.recentFrame=frameIndex;
    bank.recentAge=0; bank.updateCount=bank.updateCount+1; updated=true; source='recent';
end
if isempty(bank.best) || quality>bank.bestQuality
    bank.best=candidate; bank.bestQuality=quality; bank.bestFrame=frameIndex;
    bank.bestAge=0; updated=true; source='best';
end
bank.recentAge=frameIndex-bank.recentFrame; bank.bestAge=frameIndex-bank.bestFrame;
end
