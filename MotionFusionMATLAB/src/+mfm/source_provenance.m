function out=source_provenance()
% Record the source files that determine a run, without reading measurement truth.
% The working source directory is intentionally allowed to be outside Git.
sourceFile=mfilename('fullpath');sourceRoot=fileparts(fileparts(fileparts(sourceFile)));
out=struct('status','working_source_recorded','sourceRoot',sourceRoot,...
    'gitRoot','','gitCommit','unavailable','gitStatus','unavailable',...
    'createdUtc',datestr(now,'yyyy-mm-ddTHH:MM:SS.FFFZ'),'sourceFiles',struct([]));
cursor=sourceRoot;
while ~isempty(cursor)
    if isfolder(fullfile(cursor,'.git'))
        out.gitRoot=cursor;
        [code,txt]=system(['git -C "' cursor '" rev-parse HEAD']);
        if code==0,out.gitCommit=strtrim(txt);end
        [code,txt]=system(['git -C "' cursor '" status --short']);
        if code==0
            if isempty(strtrim(txt)),out.gitStatus='clean';else,out.gitStatus='modified';end
        end
        break;
    end
    parent=fileparts(cursor);if strcmp(parent,cursor),break;end;cursor=parent;
end
labels={'run_user_video','run_real_video','run_measurement','mfm.clean_signal',...
    'mfm.band_segments','mfm.spectrum','export_real_outputs'};
paths=cell(size(labels));
for j=1:numel(labels),paths{j}=which(labels{j});end
records=struct('label',{},'path',{},'bytes',{},'modifiedUtc',{},'sha256',{});
for j=1:numel(labels)
    p=paths{j};if isempty(p)||~isfile(p),continue;end
    d=dir(p);records(end+1).label=labels{j}; %#ok<AGROW>
    records(end).path=p;records(end).bytes=d.bytes;
    records(end).modifiedUtc=datestr(d.datenum,'yyyy-mm-ddTHH:MM:SS.FFFZ');
    records(end).sha256=sha256File(p);
end
out.sourceFiles=records;
if isempty(out.gitRoot),out.gitStatus='source_root_is_not_a_git_worktree';end
end

function hex=sha256File(path)
hex='unavailable';fid=fopen(path,'r');if fid<0,return;end
bytes=fread(fid,Inf,'*uint8');fclose(fid);
try
    md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);
    digest=typecast(md.digest(),'uint8');hex=lower(reshape(dec2hex(digest,2).',1,[]));
catch
    % Provenance remains useful with path/size/time if Java is unavailable.
end
end
