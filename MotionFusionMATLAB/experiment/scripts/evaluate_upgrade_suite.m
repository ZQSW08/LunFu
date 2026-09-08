function evaluate_upgrade_suite(parent)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
% Only call after video algorithms/configurations have been frozen.
names={'2-5mvpp-motion','4-25mvpp-motion','4-25mvpp-luandong','2-5mvpp-static','4-25mvpp-static','man-qiao'};
rows=table();
for k=1:numel(names)
    laser=fullfile('E:/sanjiao/0819',[names{k} '.csv']);if k==6,laser='E:/sanjiao/0726/man-qiao.csv';end
    result=compare_laser_v2(fullfile(parent,names{k}),laser,100,3);
    if ~isempty(result),t=struct2table(result);t.videoName=repmat(names(k),height(t),1);rows=[rows;t];end %#ok<AGROW>
end
writetable(rows,fullfile(parent,'comparison_all.csv'));
end



