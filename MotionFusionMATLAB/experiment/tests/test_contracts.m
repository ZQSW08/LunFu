function test_contracts()
% Observable geometry, missingness, coordinates, and same-frequency rejection.
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
rois=[200 80 40 40;80 200 40 40;320 200 40 40];centers=rois(:,1:2)+(rois(:,3:4)-1)/2;
theta=.07;A=[cos(theta) -sin(theta);sin(theta) cos(theta)];offset=[45 -18];q=centers*A'+offset;dd=q-centers;micro=[.2 -.1];dd(1,:)=dd(1,:)+micro;
[macro,B,ok]=mfm.compensate(dd,true(3,1),rois,'similarity');assert(ok&&norm(B-A,'fro')<1e-10);assert(norm(dd(1,:)-macro-micro)<1e-10);
[~,~,ok]=mfm.compensate(dd,[true false false],rois,'translation');assert(~ok);
[~,~,ok]=mfm.compensate(dd,[true true false],rois,'similarity');assert(~ok);
t=(0:239)'/60;total=55.35*sin(2*pi*6.7*t);ref=55*sin(2*pi*6.7*t);assert(max(abs((total-ref)-.35*sin(2*pi*6.7*t)))<1e-12);
% Same observed trajectory admits infinitely many temporal decompositions.
alternativeMacro=54*sin(2*pi*6.7*t);alternativeMicro=1.35*sin(2*pi*6.7*t);assert(max(abs(total-alternativeMacro-alternativeMicro))<1e-12);
x=sin(2*pi*13*(0:999)'/100);x(450:470)=NaN;y=mfm.band_segments(x,100,[5 45]);assert(all(isnan(y(450:470))));assert(all(isfinite(y([100 800]))));
fprintf('PASS: similarity mapping; missing-reference rejection; same-frequency spatial separation; non-identifiability; gap preservation.\n');
end


