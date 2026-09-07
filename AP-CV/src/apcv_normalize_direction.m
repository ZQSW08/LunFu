function direction = apcv_normalize_direction(value)
%APCV_NORMALIZE_DIRECTION 将用户配置的 x/y 方向统一为内部名称。
% 为兼容旧配置，也接受 horizontal/vertical；新入口建议直接填写 x 或 y。

direction = lower(strtrim(char(value)));
switch direction
    case {'x', 'horizontal'}
        direction = 'horizontal';
    case {'y', 'vertical'}
        direction = 'vertical';
    otherwise
        error('方向配置必须为 x 或 y。');
end
end
