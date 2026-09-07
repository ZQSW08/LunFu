function similar = select_similar_tasks(populations, count, sigma)
%SELECT_SIMILAR_TASKS 对所有任务按 Eq. (23) 选取最小 MMD 邻居。
K = numel(populations); similar = cell(K,1);
for i = 1:K
    distance = inf(1,K);
    for j = 1:K
        if i ~= j, distance(j) = mmd_unbiased(populations{i}, populations{j}, sigma); end
    end
    [~, order] = sort(distance, 'ascend');
    similar{i} = order(1:min(count,K-1));
end
end
