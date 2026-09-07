function [target,refs,provenance,model,samples,guideMode]=resolve_rois(u,im)
% Geometry only. No video-name-specific tracker/model/sample configuration.
root=fileparts(fileparts(mfilename('fullpath')));workspace=fileparts(root);
[~,name]=fileparts(u.videoPath);target=u.targetROI;refs=u.referenceROIs;
provenance=struct('targetSource','explicit targetROI','referenceSource','explicit referenceROIs','video',u.videoPath);
model=u.referenceModel;samples=u.maxSamples;guideMode='geometry';
assert(any(strcmp(model,{'none','auto','translation','similarity'})),'Unknown referenceModel');
assert(any(strcmp(u.referenceSelection,{'manual','interactive','automatic'})),'Unknown referenceSelection');
if strcmp(u.roiMode,'saved')
    source=u.roiSource;
    if isempty(source)
        options={fullfile(workspace,'MPME','outputs','0819',name,'real_data_result.mat'),...
                 fullfile(workspace,'MPME','outputs','07-26_single',name,'real_data_result.mat')};
        found=options(cellfun(@isfile,options));
        assert(numel(found)==1,'Saved ROI missing or ambiguous: set roiSource or roiMode=interactive');
        source=found{1};
    end
    s=load(source,'roi');assert(isfield(s,'roi')&&numel(s.roi)==4,'Source needs roi=[x y w h]');
    target=double(s.roi(:)');provenance.targetSource=source;
elseif strcmp(u.roiMode,'interactive')
    target=choose('框选同一测量目标，双击确认');provenance.targetSource='interactive target selection';
elseif ~strcmp(u.roiMode,'manual')
    error('roiMode must be saved/manual/interactive');
end
assert(isnumeric(target)&&isvector(target)&&numel(target)==4,'Missing target ROI');target=target(:)';
if strcmp(model,'none')
    assert(isempty(refs),'referenceModel=none requires empty referenceROIs');
    refs=zeros(0,4);provenance.referenceSource='explicit none; total displacement only';
elseif strcmp(u.referenceSelection,'automatic')
    assert(any(strcmp(model,{'auto','translation'})),'Automatic reference selection estimates translation only');
    model='translation';cfg=mfm.defaults();fields={'automaticReferenceCount','automaticPatchSize','automaticMinReferences','automaticMinInlierRatio','automaticConsensusTolerance','automaticMaxSpread','automaticAmbiguityRatio'};
    for j=1:numel(fields),cfg.(fields{j})=u.(fields{j});end
    [refs,selection]=mfm.select_reference_patches(im,target,u.searchROI,cfg);
    if size(refs,1)<u.automaticMinReferences,error('mfm:MissingAutomaticReference','Automatic selection found %d observable patches; need at least %d. Supply a same-body searchROI or use manual references.',size(refs,1),u.automaticMinReferences);end
    provenance.referenceSource='automatic first-frame texture patches';provenance.searchROI=selection.searchROI;
    provenance.referenceCandidateCount=selection.candidateCount;provenance.referenceScores=selection.selectedScores;
    provenance.referenceSelectionStatus=selection.status;provenance.targetExcluded=selection.targetExcluded;
elseif isempty(refs)
    if strcmp(u.referenceSelection,'interactive')
        refs=choose('框选随同宏观运动但不发生局部振动的参考，双击确认');
        provenance.referenceSource='interactive reference selection';
        if strcmp(model,'similarity'),refs(2,:)=choose('框选第二个分离的刚性参考，双击确认');end
    else
        error('mfm:MissingReference','Fill referenceROIs, set referenceSelection=interactive, or explicitly set referenceModel=none (total displacement only).');
    end
end
if strcmp(model,'auto')
    if size(refs,1)>=2,model='similarity';else,model='translation';end
end
if isempty(samples),samples=6500;end
if strcmp(model,'similarity'),assert(size(refs,1)>=2,'Similarity needs two references');end
if ~isempty(refs),assert(isnumeric(refs)&&size(refs,2)==4,'referenceROIs must be N-by-4');end
allrois=[target;refs];assert(all(isfinite(allrois(:))),'ROI has nonfinite coordinates');allrois=round(allrois);
assert(all(allrois(:,1)>=1&allrois(:,2)>=1&allrois(:,3)>=12&allrois(:,4)>=12&allrois(:,1)+allrois(:,3)-1<=size(im,2)&allrois(:,2)+allrois(:,4)-1<=size(im,1)),'ROI outside first frame');
target=allrois(1,:);refs=allrois(2:end,:);provenance.targetROI=target;provenance.referenceROIs=refs;
provenance.model=model;provenance.maxSamples=samples;provenance.guideMode=guideMode;
provenance.referenceSelection=u.referenceSelection;
    function roi=choose(titleText)
        f=figure('Name',titleText,'NumberTitle','off');imshow(im,[]);title(titleText);h=drawrectangle();wait(h);
        if ~isvalid(f)||~isvalid(h),error('ROI selection cancelled');end
        roi=round(h.Position);close(f);
    end
end
