function save_tddm_process_frame(frameIndex, previousFrame, currentFrame, localROI, ...
    pT, pD, pCor, pFinal, nccT, nccD, q, info, outputRoot, det)
%SAVE_TDDM_PROCESS_FRAME 保存 TDDM 关键中间量的代表性可视化。
% 保留论文方法链中 tracking、local detection、fusion 和 deformable matching 的证据。
if ~isfolder(outputRoot), mkdir(outputRoot); end
if nargin < 13, det=[]; end
fig=figure('Visible','off','Color','w','Position',[100 100 1100 760]);
subplot(2,3,1); imshow(previousFrame,[]); hold on; plot(pT(1),pT(2),'r+','LineWidth',1.5,'MarkerSize',10); title('Previous frame / tracking reference');
subplot(2,3,2); imshow(currentFrame,[]); hold on;
handles=gobjects(0); labels={};
if all(isfinite(pT)), handles(end+1)=plot(pT(1),pT(2),'r+','LineWidth',1.5,'MarkerSize',10); labels{end+1}='p_T'; end
if all(isfinite(pD)), handles(end+1)=plot(pD(1),pD(2),'bs','LineWidth',1.5,'MarkerSize',8); labels{end+1}='p_D'; end
if all(isfinite(pCor)), handles(end+1)=plot(pCor(1),pCor(2),'g^','LineWidth',1.5,'MarkerSize',8); labels{end+1}='p_{cor}'; end
if all(isfinite(pFinal)), handles(end+1)=plot(pFinal(1),pFinal(2),'kx','LineWidth',1.5,'MarkerSize',9); labels{end+1}='p_{final}'; end
if ~isempty(handles), legend(handles,labels,'Location','southoutside'); end
title('Current frame / TDDM outputs');
subplot(2,3,3); imshow(localROI,[]); title('Local detection ROI');
subplot(2,3,4); if ~isempty(det) && isfield(det,'enhanced'), imshow(det.enhanced,[]); title('CLAHE / enhanced ROI'); else, imshow(localROI,[]); title('Enhanced ROI unavailable'); end
subplot(2,3,5); if ~isempty(det) && isfield(det,'edgeMask'), imshow(det.edgeMask,[]); title('Canny edge evidence'); else, axis off; end
subplot(2,3,6); axis off;
text(0.02,0.88,sprintf('Frame: %d',frameIndex),'FontSize',11);
text(0.02,0.72,sprintf('NCC_T: %.5f',nccT),'FontSize',11);
text(0.02,0.58,sprintf('NCC_D: %.5f',nccD),'FontSize',11);
text(0.02,0.44,sprintf('ZNSSD: %.5f',info.ZNSSD),'FontSize',11);
text(0.02,0.30,sprintf('IC-GN iterations: %d',info.iterations),'FontSize',11);
text(0.02,0.16,sprintf('q = [%.4f %.4f %.3g %.3g %.3g %.3g]',q),'FontSize',9,'Interpreter','none');
exportgraphics(fig,fullfile(outputRoot,sprintf('frame_%04d.png',frameIndex)),'Resolution',150); close(fig);
end
