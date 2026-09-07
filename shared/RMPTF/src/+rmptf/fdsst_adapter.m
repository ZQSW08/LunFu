function bbox = fdsst_adapter(videoPath, initialRoi, maxFrames, cfg)
%FDSST_ADAPTER 将现有 improved fDSST 统一成 N x 4 bbox 粗轨迹。
root=char(cfg.tracker.fdsstRoot);
if isempty(root)
    managerRoot=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    candidates={fullfile(managerRoot,'MPME','third_party','fdsst_sunjiajian'), ...
        fullfile(managerRoot,'BPAF','third_party','fdsst_sunjiajian'), ...
        fullfile(managerRoot,'AP-CV','third_party','fdsst_sunjiajian')};
    found=find(cellfun(@(p)isfile(fullfile(p,'DSST_Function.m')),candidates),1);
    if isempty(found), error('未找到 DSST_Function.m；请设置 cfg.tracker.fdsstRoot。'); end
    root=candidates{found};
end
assert(isfile(fullfile(root,'DSST_Function.m')),'fDSST 根目录无 DSST_Function.m：%s',root);
oldPath=path; cleanup=onCleanup(@()path(oldPath)); %#ok<NASGU>
safeRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))),'fdsst_safe');
addpath(root,'-end');
if cfg.tracker.useSafeMatlabFeatures && isfolder(safeRoot), addpath(safeRoot,'-begin'); end
reader=VideoReader(videoPath);
if isfield(cfg,'io') && isfield(cfg.io,'startSeconds')
    reader.CurrentTime=min(max(0,cfg.io.startSeconds),max(0,reader.Duration-1/max(reader.FrameRate,eps)));
end
if isinf(maxFrames), maxFrames=max(1,floor((reader.Duration-reader.CurrentTime)*reader.FrameRate)); end
bbox=double(DSST_Function(round(initialRoi),reader,max(1,round(maxFrames))));
if isempty(bbox) || size(bbox,2)~=4, error('fDSST 返回值必须是 N x 4 bbox。'); end
bbox=bbox(1:min(size(bbox,1),round(maxFrames)),:);
bad=~all(isfinite(bbox),2) | bbox(:,3)<4 | bbox(:,4)<4;
bbox(bad,:)=NaN;
end
