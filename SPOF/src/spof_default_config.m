function cfg = spof_default_config()
% SPOF_DEFAULT_CONFIG 返回与论文算法对应的默认参数。
% 关键参数含义：Gabor 波长单位为像素，alpha 是边缘/平滑先验权重，
% tau 和 tauC 分别是异常后验概率下限和置信度上限。

cfg = struct();
cfg.gabor.lambda = 8;
cfg.gabor.sigma = 0.56 * cfg.gabor.lambda;
cfg.gabor.gamma = 0.5;
cfg.gabor.psi = 0;
cfg.gabor.kernelRadius = ceil(3 * cfg.gabor.sigma);
cfg.gabor.orientations = [0, pi/2];
% 论文给出 Gabor 波长和相位-位移关系，但未规定空间梯度的数值实现。
% 默认使用 Gabor 名义载频 2*pi/lambda，避免低纹理局部梯度退化。
cfg.useNominalSpatialFrequency = true;
cfg.alpha = 0.7;
cfg.edgeExponent = 2;
cfg.smoothWindow = 5;
cfg.minAmplitude = 1e-4;
cfg.minPhaseGradient = 0.02;
cfg.tau = 0.5;
cfg.tauC = 0.5;
cfg.localWindow = 5;
cfg.gmm.maxIter = 100;
cfg.gmm.tol = 1e-5;
cfg.gmm.minVariance = 1e-6;
cfg.gmm.minWeight = 1e-4;
cfg.keepIntermediates = true;
cfg.detrend = true;
cfg.method = 'SPOF';
cfg.scaleMmPerPixel = 1;
end
