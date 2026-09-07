function diagnostics = apcv_optimize_pyramid_level(phaseDifference, levels)
%APCV_OPTIMIZE_PYRAMID_LEVEL 实现论文式 (22)-(24) 的无参考层级优化。

numLevels = numel(levels);
sequence = cell(numLevels, 1);
for i = 1:numLevels
    cube = double(phaseDifference{i});
    sequence{i} = squeeze(mean(mean(cube, 1, 'omitnan'), 2, 'omitnan'));
    sequence{i} = sequence{i}(:);
end

pairR2 = nan(numLevels-1, 1);
pairResidual = nan(numLevels-1, 1);
fitSlope = nan(numLevels-1, 1);
fitIntercept = nan(numLevels-1, 1);
for i = 1:numLevels-1
    x = sequence{i}; y = sequence{i+1};
    design = [x, ones(size(x))];
    beta = design \ y;
    prediction = design * beta;
    residual = y - prediction;
    pairResidual(i) = norm(residual) / max(norm(y-mean(y)), eps);
    pairR2(i) = 1 - sum(residual.^2) / max(sum((y-mean(y)).^2), eps);
    fitSlope(i) = beta(1);
    fitIntercept(i) = beta(2);
end

% 最佳相邻层对取最大决定系数；在该层对中选择相位幅值更大的层。
[~, candidate] = max(pairR2);
rmsLower = sqrt(mean(sequence{candidate}.^2));
rmsUpper = sqrt(mean(sequence{candidate+1}.^2));
if rmsLower >= rmsUpper
    selectedIndex = candidate;
else
    selectedIndex = candidate + 1;
end

diagnostics.sequence = sequence;
diagnostics.pairR2 = pairR2;
diagnostics.pairResidual = pairResidual;
diagnostics.fitSlope = fitSlope;
diagnostics.fitIntercept = fitIntercept;
diagnostics.candidatePair = [levels(candidate), levels(candidate+1)];
diagnostics.selectedIndex = selectedIndex;
diagnostics.selectedLevel = levels(selectedIndex);
end
