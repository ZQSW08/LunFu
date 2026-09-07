function [macro,A,valid]=compensate(displacements,mask,rois,model)
% Fit reference geometry only; target NEVER participates in nuisance fit.
centers=rois(:,1:2)+(rois(:,3:4)-1)/2;
if strcmp(model,'none')
    macro=[0 0];A=eye(2);valid=true;return;
end
ids=find(mask(2:end))+1;macro=[NaN NaN];A=nan(2);valid=false;
if isempty(ids),return;end
if strcmp(model,'translation')
    macro=median(displacements(ids,:),1);A=eye(2);
else
    if numel(ids)<2,return;end
    p=centers(ids,:);q=p+displacements(ids,:);pc=mean(p,1);qc=mean(q,1);p=p-pc;q=q-qc;den=sum(p(:).^2);
    if den<25,return;end
    a=sum(p(:).*q(:))/den;b=sum(p(:,1).*q(:,2)-p(:,2).*q(:,1))/den;A=[a -b;b a];
    if hypot(a,b)<.5||hypot(a,b)>2,return;end
    macro=(centers(1,:)-pc)*A'+qc-centers(1,:);
end
valid=true;
end
