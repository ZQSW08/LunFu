function test_auto_reference()
% Geometry-only automatic-reference contracts; no video or temporal fitting.
root=fileparts(mfilename('fullpath'));addpath(root);c=mfm.defaults();
targetTotal=[80 -50];refs=repmat([3.2 -1.7],5,1)+[0 0;.05 -.03;-.04 .02;.02 .04;-.03 -.02];
[m,ok,d]=mfm.reference_consensus(refs,true(5,1),c);assert(ok&&d.support==5&&norm(m-[3.2 -1.7])<.03);
assert(norm((targetTotal-m)-[76.8 -48.3])<.03,'Target displacement entered reference estimate');
[m,ok,d]=mfm.reference_consensus([zeros(3,2);repmat([4 0],3,1)],true(6,1),c);assert(~ok&&all(isnan(m))&&strcmp(d.status,'ambiguous_motion_groups'));
[~,ok,d]=mfm.reference_consensus([1 2;1 2],true(2,1),c);assert(~ok&&strcmp(d.status,'insufficient_valid_references'));
[~,ok,d]=mfm.reference_consensus([zeros(3,2);4 0;8 0;12 0],true(6,1),c);assert(~ok&&strcmp(d.status,'insufficient_inlier_ratio'));
[~,ok,d]=mfm.reference_consensus([-1 0;0 0;1 0],true(3,1),c);assert(~ok&&strcmp(d.status,'excessive_reference_spread'));
t=(0:239)'/60;macro=[12*sin(2*pi*6.7*t) 5*cos(2*pi*6.7*t)];micro=.35*sin(2*pi*6.7*t);relative=nan(size(micro));
for k=1:numel(t),[m,ok]=mfm.reference_consensus(repmat(macro(k,:),5,1),true(5,1),c);assert(ok);relative(k)=macro(k,1)+micro(k)-m(1);end
assert(max(abs(relative-micro))<1e-12,'Same-frequency motion was not spatially separated');
[m,ok]=mfm.reference_consensus(repmat([2.5 -4.25],5,1),true(5,1),c);assert(ok&&norm(m-[2.5 -4.25])<1e-12,'xy/y translation failed');
[mt,ok]=mfm.reference_consensus(repmat([-4.25 2.5],5,1),true(5,1),c);assert(ok&&norm(mt([2 1])-[2.5 -4.25])<1e-12,'axis=y transpose convention failed');
im=30*ones(180,260);[X,Y]=meshgrid(1:260,1:180);texture=45*sin(.31*X)+38*cos(.27*Y);im(21:160,21:240)=120+texture(21:160,21:240);im=uint8(min(255,max(0,im)));
target=[95 65 60 50];u=mfm.real_defaults();u.videoPath='synthetic_identity.avi';u.roiMode='manual';u.targetROI=target;u.referenceSelection='automatic';u.referenceModel='translation';u.searchROI=[20 20 220 140];
[r,refs,p,model]=mfm.resolve_rois(u,im);assert(isequal(r,target)&&strcmp(model,'translation')&&size(refs,1)>=u.automaticMinReferences);
assert(strcmp(p.referenceSource,'automatic first-frame texture patches')&&isequal(p.searchROI,u.searchROI)&&p.targetExcluded);
for j=1:size(refs,1),assert(~rect_overlap(refs(j,:),target),'Automatic patch overlaps target');end
centers=refs(:,1:2)+(refs(:,3:4)-1)/2;for j=1:size(refs,1),for q=j+1:size(refs,1),assert(norm(centers(j,:)-centers(q,:))>=.9*u.automaticPatchSize,'Automatic patches are not dispersed');end,end
u.searchROI=[];flat=uint8(80*ones(size(im)));threw=false;try,mfm.resolve_rois(u,flat);catch ex,threw=strcmp(ex.identifier,'mfm:MissingAutomaticReference');end
assert(threw,'Unobservable automatic references were accepted');
fprintf('AUTO REFERENCE PASS: target exclusion; ambiguity/missingness rejection; same-frequency separation; xy/y; provenance.\n');
end
function yes=rect_overlap(a,b)
yes=a(1)<=b(1)+b(3)-1&&b(1)<=a(1)+a(3)-1&&a(2)<=b(2)+b(4)-1&&b(2)<=a(2)+a(4)-1;
end
