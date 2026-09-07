function [q, info] = translation_icgn(reference, current, refCenter, q0, cfg)
%TRANSLATION_ICGN 仅保留 [u,v] 的 IC-GN 消融版本。
r=floor(cfg.paper.templateSize/2); [X,Y]=meshgrid(-r:r,-r:r);
cx=refCenter(1);cy=refCenter(2);
T=interp2(double(reference),cx+X,cy+Y,cfg.impl.interpolation,NaN);
if any(isnan(T(:))), error('Reference subset outside image.'); end
if cfg.impl.useZNNormalization
    [Tn,~,st]=normalize_patch(T);
else
    Tn=T; st=1;
end
[Gx,Gy]=gradient(T); SD=[Gx(:),Gy(:)]/st;
H=SD'*SD+eye(2)*cfg.impl.icgnDamping; q=q0(:); q(3:6)=0;
converged=false; last=Inf;
for iter=1:cfg.impl.icgnMaxIter
    Iw=interp2(double(current),cx+X+q(1),cy+Y+q(2),cfg.impl.interpolation,NaN);
    if any(isnan(Iw(:))),break;end
    if cfg.impl.useZNNormalization, [In,~,si]=normalize_patch(Iw); else, In=Iw;si=1;end
    if si<1e-12,break;end
    residual=Tn-In; delta=-(H\(SD'*residual(:)));
    q(1:2)=q(1:2)-delta; last=sum(residual(:).^2);
    if norm(delta)<cfg.impl.icgnTolerance, converged=true;break;end
end
if ~exist('iter','var'),iter=0;end
info=struct('converged',converged,'iterations',iter,'ZNSSD',last,'engine','translation');
end
