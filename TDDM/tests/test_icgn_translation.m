function report = test_icgn_translation(cfg)
%TEST_ICGN_TRANSLATION 用 0.25 pixel 平移检验参考到当前的正方向。
oldEngine = cfg.impl.icgnEngine;
cfg.impl.icgnEngine = 'adic2d';
sz = [160 160]; [X,Y] = meshgrid(1:sz(2),1:sz(1));
I = 0.5 + 0.2*sin(X/7) + 0.15*cos(Y/11) + 0.1*sin((X+Y)/17);
J = interp2(I, X-0.25, Y, 'cubic', 0);
center = [80 80]; q0=zeros(6,1);
[qA,infoA] = affine_icgn(I,J,center,q0,cfg);
cfg.impl.icgnEngine = 'native';
[qN,infoN] = affine_icgn(I,J,center,q0,cfg);
assert(abs(qA(1)-0.25) < 0.03 && abs(qA(2)) < 0.03, 'ADIC2D IC-GN translation check failed.');
assert(abs(qN(1)-0.25) < 0.03 && abs(qN(2)) < 0.03, 'Native IC-GN translation check failed.');
report = struct('adic2d',qA,'native',qN,'adic2dInfo',infoA,'nativeInfo',infoN,'passed',true);
cfg.impl.icgnEngine = oldEngine; %#ok<NASGU>
end
