function [center, ok, diagnostics] = intersect_phase_lines(line1, line2)
%INTERSECT_PHASE_LINES 联立 a*x+b*y+c=0 的两条直线求中心。
A = [line1.a, line1.b; line2.a, line2.b];
c = [line1.c; line2.c];
detA = det(A);
ok = all(isfinite(A(:))) && all(isfinite(c)) && abs(detA) > 1e-8;
if ok
    center = (A \ (-c)).';
else
    center = [NaN NaN];
end
diagnostics = struct('determinant',detA,'condition',cond(A));
end
