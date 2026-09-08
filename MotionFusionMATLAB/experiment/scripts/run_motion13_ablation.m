function run_motion13_ablation()
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
% Fixed alternatives declared before comparison. Preserve every run.
tags={'dense_reference','translation_reference','taller_target','wide_reference'};
for i=1:numel(tags)
    c=mfm.defaults();c.video='C:/0819/2-5mvpp-motion.avi';c.fps=100;
    c.rois=[1281 681 50 75;1135 825 62 110];
    switch tags{i}
        case 'dense_reference',c.maxSamples=6500;
        case 'translation_reference',c.maxSamples=6500;c.affine=false;
        case 'taller_target',c.maxSamples=6500;c.rois(1,:)=[1281 676 50 85];
        case 'wide_reference',c.maxSamples=12000;c.rois(2,:)=[1131 797 75 144];
    end
    c.output=fullfile(root,'outputs',tags{i},'motion13');run_measurement(c);evaluate_laser(tags{i});
end
end



