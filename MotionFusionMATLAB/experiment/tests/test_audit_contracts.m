function test_audit_contracts()
% No real laser required; executable boundaries for raw output and ROI modes.
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
im=uint8(80*ones(180,240));u=mfm.real_defaults();u.videoPath='arbitrary_unseen_name.avi';
u.roiMode='manual';u.targetROI=[20 30 40 50];u.referenceROIs=[100 80 40 50];
[roi,refs,~,model,samples,guide]=mfm.resolve_rois(u,im);
assert(isequal(roi,u.targetROI)&&isequal(refs,u.referenceROIs));
assert(strcmp(model,'translation')&&samples==6500&&strcmp(guide,'geometry'));
u.videoPath='2-5mvpp-motion.avi';[r2,q2,~,m2,s2,g2]=mfm.resolve_rois(u,im);
assert(isequal(roi,r2)&&isequal(refs,q2)&&strcmp(model,m2)&&samples==s2&&strcmp(guide,g2),'Filename changed numerical configuration');
u.referenceROIs=[];threw=false;try,mfm.resolve_rois(u,im);catch ex,threw=strcmp(ex.identifier,'mfm:MissingReference');end
assert(threw,'Missing references silently changed measurement semantics');
u.referenceModel='none';[~,ref,~,model]=mfm.resolve_rois(u,im);assert(isempty(ref)&&strcmp(model,'none'));
u.targetROI=[NaN 30 40 50];threw=false;try,mfm.resolve_rois(u,im);catch,threw=true;end;assert(threw);
rng(409);x=randn(300,1);x(70:80)=NaN;s=mfm.clean_signal(x,100,[],false);
assert(isequaln(s.raw,x)&&isequaln(s.broad,x)&&isequaln(s.clean,x));
assert(strcmp(s.status,'unfiltered_measurement')&&isempty(s.modesHz));
test_contracts();
fprintf('AUDIT CONTRACT PASS: filename invariance; explicit references; finite ROI; exact raw passthrough; gaps preserved.\n');
end



