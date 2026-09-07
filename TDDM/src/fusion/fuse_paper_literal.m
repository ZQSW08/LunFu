function dCor = fuse_paper_literal(dT, dD, pDminusT, nccT, nccD, gate)
%FUSE_PAPER_LITERAL 保留论文 Eq.(10) 的局部位移写法，供对照实验使用。
if nccD < gate
    dCor = pDminusT + dT;
elseif nccT < gate
    dCor = pDminusT + dD;
else
    [wT, wD] = confidence_weights(nccT, nccD);
    dCor = pDminusT + wT * dT + wD * dD;
end
end
