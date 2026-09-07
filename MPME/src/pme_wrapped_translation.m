function displacement = pme_wrapped_translation(reference, moving, params)
%PME_WRAPPED_TRANSLATION Classical single-scale principal-phase PME.
% Returns the component along the selected Gabor orientation and therefore
% explicitly exhibits the +/-lambda/2 phase-wrapping limit.

theta = params.directions(1);
q1 = gabor_response(reference, params.lambda, theta, params.bandwidth, ...
    params.psi, params.supportSigma);
q2 = gabor_response(moving, params.lambda, theta, params.bandwidth, ...
    params.psi, params.supportSigma);
weight = abs(q1) .* abs(q2);
[~, peakIndex] = max(weight(:));
[row, column] = ind2sub(size(weight), peakIndex);
rowMinus = max(1, row-1); rowPlus = min(size(weight,1), row+1);
columnMinus = max(1, column-1); columnPlus = min(size(weight,2), column+1);
gx1 = 0.5 * angle(q1(row, columnPlus) * conj(q1(row, columnMinus)));
gx2 = 0.5 * angle(q2(row, columnPlus) * conj(q2(row, columnMinus)));
gy1 = 0.5 * angle(q1(rowPlus, column) * conj(q1(rowMinus, column)));
gy2 = 0.5 * angle(q2(rowPlus, column) * conj(q2(rowMinus, column)));
circularPhase = angle(q2(row,column) * conj(q1(row,column)));
thetaRad = deg2rad(theta);
directionalGradient = cos(thetaRad) * 0.5*(gx1+gx2) + ...
    sin(thetaRad) * 0.5*(gy1+gy2);
component = -circularPhase / directionalGradient;
displacement = [component*cos(thetaRad), component*sin(thetaRad)];
end
