function result = mato_optimize(video, truth, taskPixels, cfg, theta0)
%MATO_OPTIMIZE MaTO 的可运行复现：AMP + MMD + GA/局部 EDA。
% 论文 Algorithm 1-3 没有公开全部 GA/EDA 超参数；相关推断参数均来自
% cfg.mato，并在结果中保存，保证每次实验可追溯。
if nargin < 5 || isempty(theta0), theta0 = cfg.loggabor.theta0; end
rng(cfg.randomSeed + 17, 'twister');
% 真实首帧训练可使用解析 Fourier shift，避免保存训练视频的三维 FFT。
useReferenceTraining=isfield(cfg,'optimization') && ...
    isfield(cfg.optimization,'trainingReference') && isfield(cfg.optimization,'trainingDisplacementXY');
videoSpectrum=[]; referenceSpectrum=[]; trainingDisplacementXY=[];
if useReferenceTraining
    referenceSpectrum=fftshift(fftshift(fft2(cfg.optimization.trainingReference),1),2);
    trainingDisplacementXY=cfg.optimization.trainingDisplacementXY;
else
    % 普通小规模模拟任务：训练视频固定，FFT 只计算一次。
    videoSpectrum=fftshift(fftshift(fft2(video),1),2);
end
lower = [cfg.loggabor.habRange(1), cfg.loggabor.rsdRange(1), cfg.loggabor.asdRange(1)];
upper = [cfg.loggabor.habRange(2), cfg.loggabor.rsdRange(2), cfg.loggabor.asdRange(2)];
K = size(taskPixels,1); N = cfg.mato.populationSize; G = cfg.mato.generations;
populations = cell(K,1); fitness = cell(K,1); history = nan(K,G);
ampHistory = nan(K,G); similarHistory = cell(K,G);
bestX = zeros(K,3); bestFitness = inf(K,1);
for i = 1:K
    populations{i} = lower + rand(N,3).*(upper-lower);
    fitness{i} = evaluate_population(populations{i}, taskPixels(i,:));
    [bestFitness(i), ix] = min(fitness{i}); bestX(i,:) = populations{i}(ix,:);
end
% 论文 Algorithm 3 先执行三代 intra-task GA；这里严格保留这一阶段。
for g = 1:min(3,G)
    for i = 1:K
        [populations{i}, fitness{i}] = ga_generation(populations{i}, fitness{i}, taskPixels(i,:));
        [bestFitness(i), ix] = min(fitness{i}); bestX(i,:) = populations{i}(ix,:);
        history(i,g) = bestFitness(i);
    end
end
for g = 4:G
    similar = select_similar_tasks(populations, cfg.mato.similarCount, cfg.mato.kernelWidth);
    for i = 1:K
        amp = adaptive_mating_probability(history(i, g-2:g-1));
        ampHistory(i,g) = amp; similarHistory{i,g} = similar{i};
        if rand <= amp && ~isempty(similar{i})
            offspring = eda_transfer(populations, fitness, i, similar{i});
        else
            [nextPop, nextFit] = ga_generation(populations{i}, fitness{i}, taskPixels(i,:));
            populations{i}=nextPop; fitness{i}=nextFit; offspring=[];
        end
        if ~isempty(offspring)
            offFit = evaluate_population(offspring, taskPixels(i,:));
            [allFit, order] = sort([fitness{i}; offFit], 'ascend');
            allPop = [populations{i}; offspring];
            populations{i}=allPop(order(1:N),:); fitness{i}=allFit(1:N);
        end
        [bestFitness(i), ix] = min(fitness{i}); bestX(i,:) = populations{i}(ix,:);
        history(i,g) = bestFitness(i);
    end
end
result.taskPixels = taskPixels;
result.bestX = bestX;
result.bestFitness = bestFitness;
result.history = history;
result.ampHistory = ampHistory;
result.similarHistory = similarHistory;
result.populations = populations;
result.fitness = fitness;
result.config = cfg.mato;

    function values = evaluate_population(P, pixel)
        values = zeros(size(P,1),1);
        for n = 1:size(P,1)
            if useReferenceTraining
                values(n)=objective_rmse_from_reference(P(n,:),referenceSpectrum,trainingDisplacementXY,cfg,pixel,theta0);
            else
                values(n)=objective_rmse_at_pixel(P(n,:),videoSpectrum,truth_for_task(pixel),cfg,pixel,theta0);
            end
        end
    end

    function taskTruth = truth_for_task(pixel)
        index = find(taskPixels(:,1)==pixel(1) & taskPixels(:,2)==pixel(2), 1);
        if isvector(truth)
            taskTruth = truth;
        elseif size(truth,1) == K
            if isempty(index), error('taskPixels 中缺少当前任务坐标。'); end
            taskTruth = truth(index,:);
        else
            error('truth 必须是 T×1、1×T 或 K×T。');
        end
    end

    function [nextPop,nextFit] = ga_generation(P,F,pixel)
        offspring = zeros(N,3);
        for q = 1:2:N
            p1 = tournament(P,F); p2 = tournament(P,F);
            [offspring(q,:), c2] = crossover_mutation(p1,p2,lower,upper,cfg);
            if q+1 <= N, offspring(q+1,:) = c2; end
        end
        offFit=evaluate_population(offspring,pixel);
        [allFit,order]=sort([F;offFit],'ascend'); allPop=[P;offspring];
        nextPop=allPop(order(1:N),:); nextFit=allFit(1:N);
    end

    function offspring = eda_transfer(allP,allF,target,neighbors)
        pool = allP{target}; poolF = allF{target};
        for n = neighbors(:)'
            keep = max(1, round(cfg.mato.eliteFraction*size(allP{n},1)));
            [~,ix] = sort(allF{n},'ascend'); pool=[pool;allP{n}(ix(1:keep),:)]; poolF=[poolF;allF{n}(ix(1:keep))]; %#ok<AGROW>
        end
        keep = max(3, round(cfg.mato.eliteFraction*size(pool,1)));
        [~,ix] = sort(poolF,'ascend'); elite=pool(ix(1:keep),:);
        C=min([cfg.mato.clusterCount, size(elite,1)]);
        labels = local_kmeans(elite,C);
        offspring=zeros(N,3);
        for q=1:N
            cluster=labels(randi(C)); sample=elite(labels==cluster,:);
            if size(sample,1)<2, sample=elite; end
            mu=mean(sample,1); sd=std(sample,0,1); sd=max(sd,0.01*(upper-lower));
            offspring(q,:)=min(max(mu+sd.*randn(1,3),lower),upper);
            if any(~isfinite(offspring(q,:))), offspring(q,:)=lower+rand(1,3).*(upper-lower); end
        end
    end

    function labels = local_kmeans(X,C)
        if C==1, labels=ones(size(X,1),1); return; end
        try
            labels=kmeans(X,C,'MaxIter',30,'Replicates',1,'Display','off');
        catch
            [~,order]=sort(X(:,1)); labels=mod((1:size(X,1))'-1,C)+1; labels(order)=labels;
        end
    end
end

function amp = adaptive_mating_probability(lastTwo)
% Eq. (17)-(19)：d1 为最近两代变化，d2 为更早两代变化。
d1=abs(lastTwo(2)-lastTwo(1)); d2=max(abs(lastTwo(1)),eps);
amp=d2/(d1+d2); amp=min(max(amp,0),1);
end

function p = tournament(P,F)
ids=randi(size(P,1),[3,1]); [~,ix]=min(F(ids)); p=P(ids(ix),:);
end

function [c1,c2] = crossover_mutation(p1,p2,lower,upper,cfg)
if rand < cfg.mato.crossoverProbability
    alpha=rand(1,3); c1=alpha.*p1+(1-alpha).*p2; c2=alpha.*p2+(1-alpha).*p1;
else
    c1=p1; c2=p2;
end
for d=1:3
    span=upper(d)-lower(d);
    if rand<cfg.mato.mutationProbability, c1(d)=c1(d)+cfg.mato.mutationScale*span*randn; end
    if rand<cfg.mato.mutationProbability, c2(d)=c2(d)+cfg.mato.mutationScale*span*randn; end
end
c1=min(max(c1,lower),upper); c2=min(max(c2,lower),upper);
end
