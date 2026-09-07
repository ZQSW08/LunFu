function value = apcv_weighted_mean(field, mask)
%APCV_WEIGHTED_MEAN 对主动像素执行论文式 (16) 的二值加权平均。

valid = logical(mask) & isfinite(field);
if ~any(valid(:))
    value = NaN;
else
    value = mean(field(valid), 'omitnan');
end
end
