function result = single_task_optimize(video, truth, pixel, cfg, theta0)
%SINGLE_TASK_OPTIMIZE 论文 IPSO 的轻量 GA baseline，用于单测点对照。
if nargin < 5 || isempty(theta0), theta0 = cfg.loggabor.theta0; end
rng(cfg.randomSeed, 'twister');
lower = [cfg.loggabor.habRange(1), cfg.loggabor.rsdRange(1), cfg.loggabor.asdRange(1)];
upper = [cfg.loggabor.habRange(2), cfg.loggabor.rsdRange(2), cfg.loggabor.asdRange(2)];
N = cfg.mato.populationSize; G = cfg.mato.generations;
population = lower + rand(N,3).*(upper-lower);
fitness = evaluate_population(population);
bestHistory = zeros(G,1);
for g = 1:G
    offspring = zeros(N,3);
    for i = 1:2:N
        p1 = tournament(population, fitness); p2 = tournament(population, fitness);
        [c1,c2] = crossover_mutation(p1,p2,lower,upper,cfg);
        offspring(i,:) = c1;
        if i+1 <= N, offspring(i+1,:) = c2; end
    end
    offFitness = evaluate_population(offspring);
    [allFitness, order] = sort([fitness; offFitness], 'ascend');
    allPopulation = [population; offspring];
    population = allPopulation(order(1:N),:);
    fitness = allFitness(1:N);
    bestHistory(g) = fitness(1);
end
result.bestX = population(1,:); result.bestFitness = fitness(1);
result.population = population; result.fitness = fitness; result.history = bestHistory;

    function values = evaluate_population(P)
        values = zeros(size(P,1),1);
        for n = 1:size(P,1)
            values(n) = objective_rmse(P(n,:), video, truth, pixel, cfg, theta0);
        end
    end
end

function p = tournament(population, fitness)
ids = randi(size(population,1), [3,1]); [~,ix] = min(fitness(ids)); p = population(ids(ix),:);
end

function [c1,c2] = crossover_mutation(p1,p2,lower,upper,cfg)
if rand < cfg.mato.crossoverProbability
    alpha = rand(1,3); c1 = alpha.*p1 + (1-alpha).*p2; c2 = alpha.*p2 + (1-alpha).*p1;
else
    c1=p1; c2=p2;
end
for c = 1:3
    if rand < cfg.mato.mutationProbability
        span = upper(c)-lower(c); c1(c) = c1(c) + cfg.mato.mutationScale*span*randn;
    end
    if rand < cfg.mato.mutationProbability
        span = upper(c)-lower(c); c2(c) = c2(c) + cfg.mato.mutationScale*span*randn;
    end
end
c1=min(max(c1,lower),upper); c2=min(max(c2,lower),upper);
end
