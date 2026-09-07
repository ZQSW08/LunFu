function [template,source] = phase_template_bank_select(bank,cfg)
% PHASE_TEMPLATE_BANK_SELECT 根据年龄和质量选择跟踪模板。
% anchor 仅作为稳定兜底，不参与自适应更新。
template=bank.anchor; source='anchor';
if ~isfield(cfg.method,'templateBankEnabled') || ~cfg.method.templateBankEnabled, return; end
maxAge=cfg.method.templateMaxAgeFrames;
if isfield(bank,'recent') && ~isempty(bank.recent) && isfinite(bank.recentAge) && bank.recentAge<=maxAge
    template=bank.recent; source='recent'; return;
end
if isfield(bank,'best') && ~isempty(bank.best) && isfinite(bank.bestQuality)
    template=bank.best; source='best';
end
end
