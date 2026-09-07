function audit=run_round_laser_review(tag)
%RUN_ROUND_LASER_REVIEW Evaluate completed automatic-round outputs only.
% compare_laser_v2 writes under evaluation/ and does not receive any role in
% tracking. Measurement files are hashed before and after each evaluation.
if nargin<1||isempty(tag),error('run_round_laser_review:MissingTag','Supply the automatic round tag');end
root=fileparts(mfilename('fullpath'));addpath(root);
outRoot=fullfile(root,'outputs',char(tag));assert(isfolder(outRoot),'Output tag not found: %s',outRoot);
dirs=dir(outRoot);dirs=dirs([dirs.isdir]);dirs=dirs(~ismember({dirs.name},{'.','..','_history'}));
audit=struct([]);
for j=1:numel(dirs)
    name=dirs(j).name;folder=fullfile(outRoot,name);resultFile=fullfile(folder,'result.mat');
    if ~isfile(resultFile),continue;end
    laser=fullfile('E:/sanjiao/0819',[name '.csv']);
    before=measurementHashes(folder);entry=struct('video',name,'resultDirectory',folder,...
        'laserPath',laser,'status','','hashBefore',before,'hashAfter',before,'hashUnchanged',true,'error','');
    if ~isfile(laser)
        entry.status='missing';
    else
        try
            compare_laser_v2(folder,laser,100,3);
            entry.status='evaluated';entry.hashAfter=measurementHashes(folder);
            entry.hashUnchanged=isequaln(entry.hashBefore,entry.hashAfter);
            assert(entry.hashUnchanged,'Measurement hash changed during laser evaluation');
        catch ex
            entry.status='error';entry.error=ex.message;entry.hashAfter=measurementHashes(folder);
            entry.hashUnchanged=isequaln(entry.hashBefore,entry.hashAfter);
        end
    end
    if isempty(audit),audit=entry;else,audit(end+1)=entry;end %#ok<AGROW>
end
fid=fopen(fullfile(outRoot,'laser_review_audit.json'),'w');assert(fid>=0,'Cannot write laser audit');
fwrite(fid,jsonencode(audit,'PrettyPrint',true),'char');fclose(fid);
end

function out=measurementHashes(folder)
files=[dir(fullfile(folder,'result.mat'));dir(fullfile(folder,'traces.csv'));...
    dir(fullfile(folder,'waveform_*.csv'));dir(fullfile(folder,'spectrum_*.csv'))];
out=struct([]);
for j=1:numel(files)
    p=fullfile(folder,files(j).name);h=sha256File(p);e=struct('name',files(j).name,'sha256',h);
    if isempty(out),out=e;else,out(end+1)=e;end %#ok<AGROW>
end
end

function h=sha256File(path)
fid=fopen(path,'r');assert(fid>=0,'Cannot hash file: %s',path);bytes=fread(fid,Inf,'*uint8');fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');md.update(bytes);d=typecast(md.digest(),'uint8');
h=lower(reshape(dec2hex(d,2).',1,[]));
end
