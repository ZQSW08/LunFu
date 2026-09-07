function kernel = make_gabor_kernel(lambda, thetaDeg, bandwidth, gamma, psi, supportSigma)
%MAKE_GABOR_KERNEL Complex 2-D Gabor wavelet from paper Eq. (1).

if nargin < 3 || isempty(bandwidth), bandwidth = 1.0; end
if nargin < 4 || isempty(gamma), gamma = 1.0; end
if nargin < 5 || isempty(psi), psi = 0; end
if nargin < 6 || isempty(supportSigma), supportSigma = 2.0; end

sigma = (lambda / pi) * sqrt(log(2) / 2) * ...
    ((2^bandwidth + 1) / (2^bandwidth - 1));
radius = max(2, ceil(supportSigma * sigma));
[x, y] = meshgrid(-radius:radius, -radius:radius);
theta = deg2rad(thetaDeg);
xPrime = x * cos(theta) + y * sin(theta);
yPrime = -x * sin(theta) + y * cos(theta);
envelope = exp(-(xPrime.^2 + gamma^2 * yPrime.^2) / (2 * sigma^2));
kernel = envelope .* exp(1i * (2 * pi * xPrime / lambda + psi));
end
