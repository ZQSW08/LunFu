function [center, score, ok] = template_match_integer(reference, current, center, halfSize, searchRadius)
%TEMPLATE_MATCH_INTEGER 小范围整数 NCC 搜索，仅用于粗定位兜底和 TM 对照。
[T, validT] = extract_patch(reference, center, halfSize, 'linear');
if ~all(validT(:)) || any(isnan(T(:)))
    center = [NaN NaN]; score = NaN; ok = false; return;
end
bestScore = -Inf;
best = center;
for dy = -searchRadius:searchRadius
    for dx = -searchRadius:searchRadius
        candidate = center + [dx dy];
        [C, validC] = extract_patch(current, candidate, halfSize, 'linear');
        if all(validC(:)) && ~any(isnan(C(:)))
            s = ncc_patch(T, C);
            if s > bestScore
                bestScore = s;
                best = candidate;
            end
        end
    end
end
center = best;
score = bestScore;
ok = isfinite(bestScore);
end
