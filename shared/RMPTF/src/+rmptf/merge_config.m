function output = merge_config(defaults, supplied)
%MERGE_CONFIG 递归合并结构体配置，未知字段保留以便项目适配。
output = defaults;
if nargin < 2 || isempty(supplied), return; end
if ~isstruct(supplied), error('RMPTF 配置必须是 struct。'); end
names = fieldnames(supplied);
for k = 1:numel(names)
    name = names{k};
    if isfield(output,name) && isstruct(output.(name)) && isstruct(supplied.(name))
        output.(name) = rmptf.merge_config(output.(name),supplied.(name));
    else
        output.(name) = supplied.(name);
    end
end
end
