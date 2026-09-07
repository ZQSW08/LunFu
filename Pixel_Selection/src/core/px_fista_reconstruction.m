function sparse = px_fista_reconstruction(signal, observed, fs, cfg)
% 用正弦字典和FISTA求解L1正则化稀疏重构。
signal = double(signal(:));
observed = logical(observed(:));
time = (0:numel(signal)-1)' / fs;
frequencies = (cfg.sparse.fmin:cfg.sparse.df:cfg.sparse.fmax)';
dictionary = sin(2 * pi * time * frequencies');
dictionaryObserved = dictionary(observed, :);
target = signal(observed);
if isempty(target)
    error('时间观测掩膜为空，无法执行FISTA。');
end

% 用幂迭代估计梯度Lipschitz常数，避免调用大矩阵的完整SVD。
vector = ones(size(dictionaryObserved, 2), 1);
for iteration = 1:30
    vector = dictionaryObserved' * (dictionaryObserved * vector);
    vector = vector / max(norm(vector), eps);
end
lipschitz = norm(dictionaryObserved * vector)^2 + 1e-12;
coefficient = zeros(numel(frequencies), 1);
momentum = coefficient;
q = 1;
previousObjective = NaN;
for iteration = 1:cfg.sparse.maxIter
    residual = dictionaryObserved * momentum - target;
    gradient = dictionaryObserved' * residual;
    nextCoefficient = px_soft_threshold(momentum - gradient / lipschitz, cfg.sparse.lambda / lipschitz);
    nextQ = (1 + sqrt(1 + 4 * q^2)) / 2;
    momentum = nextCoefficient + (q - 1) / nextQ * (nextCoefficient - coefficient);
    coefficient = nextCoefficient;
    q = nextQ;
    if mod(iteration, 10) == 0 || iteration == 1
        objective = 0.5 * sum((dictionaryObserved * coefficient - target).^2) + cfg.sparse.lambda * sum(abs(coefficient));
        if isfinite(previousObjective) && abs(previousObjective - objective) <= cfg.sparse.tolerance * max(1, previousObjective)
            break;
        end
        previousObjective = objective;
    end
end

reconstructed = dictionary * coefficient;
[fftFrequency, fftSpectrum] = px_normalize_spectrum(reconstructed, fs);
[~, fftPeak] = max(fftSpectrum);
[~, coefficientPeak] = max(abs(coefficient));
sparse.frequencies = frequencies;
sparse.coefficients = coefficient;
sparse.coefficientSpectrum = abs(coefficient);
sparse.reconstructed = reconstructed;
sparse.fftFrequency = fftFrequency;
sparse.fftSpectrum = fftSpectrum;
sparse.peakFrequency = fftFrequency(fftPeak);
sparse.coefficientPeakFrequency = frequencies(coefficientPeak);
sparse.iterations = iteration;
sparse.lipschitz = lipschitz;
end

function output = px_soft_threshold(input, threshold)
% L1近端算子的软阈值函数。
output = sign(input) .* max(abs(input) - threshold, 0);
end
