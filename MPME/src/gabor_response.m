function q = gabor_response(image, lambda, thetaDeg, bandwidth, psi, supportSigma)
%GABOR_RESPONSE Fast separable response for the baseline gamma=1 Gabor.

if nargin < 4 || isempty(bandwidth), bandwidth = 1.0; end
if nargin < 5 || isempty(psi), psi = 0; end
if nargin < 6 || isempty(supportSigma), supportSigma = 2.0; end

sigma = (lambda / pi) * sqrt(log(2) / 2) * ...
    ((2^bandwidth + 1) / (2^bandwidth - 1));
radius = max(2, ceil(supportSigma * sigma));
coord = -radius:radius;
theta = deg2rad(thetaDeg);
gx = exp(-(coord.^2) / (2 * sigma^2)) .* ...
    exp(1i * 2 * pi * coord * cos(theta) / lambda);
gy = exp(-(coord.^2) / (2 * sigma^2)) .* ...
    exp(1i * 2 * pi * coord * sin(theta) / lambda) .* exp(1i * psi);

q = imfilter(double(image), gx, 'symmetric', 'conv', 'same');
q = imfilter(q, gy.', 'symmetric', 'conv', 'same');
end
