function value = mmd_unbiased(X, Y, sigma)
%MMD_UNBIASED Eq. (20)-(23) 的 Gaussian-kernel unbiased MMD^2。
if nargin < 3 || isempty(sigma), sigma = 1; end
X = double(X); Y = double(Y);
if size(X,1) < 2 || size(Y,1) < 2
    value = 0; return;
end
Kxx = gaussian_kernel(X, X, sigma);
Kyy = gaussian_kernel(Y, Y, sigma);
Kxy = gaussian_kernel(X, Y, sigma);
value = (sum(Kxx(:))-trace(Kxx))/(size(X,1)*(size(X,1)-1)) ...
      + (sum(Kyy(:))-trace(Kyy))/(size(Y,1)*(size(Y,1)-1)) ...
      - 2*mean(Kxy(:));
value = max(real(value), 0);
end

function K = gaussian_kernel(X, Y, sigma)
xx = sum(X.^2,2); yy = sum(Y.^2,2)';
d2 = max(xx + yy - 2*(X*Y'), 0);
K = exp(-d2/(2*sigma^2));
end
