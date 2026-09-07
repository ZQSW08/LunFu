function run_real_suite(tag,cases)
if nargin<1,tag='native_v1';end
if nargin<2,cases={'motion13','motion27','random27','static13','static27','bridge'};end
root=fileparts(mfilename('fullpath'));addpath(root);
for k=1:numel(cases)
    name=cases{k};c=mfm.defaults();c.fps=100;
    switch name
        case 'motion13',c.video='C:/0819/2-5mvpp-motion.avi';c.rois=[1281 681 50 75;1135 825 62 110];
        case 'motion27',c.video='C:/0819/4-25mvpp-motion.avi';c.rois=[1071 686 50 75;1184 569 45 75;920 835 70 98];c.referenceModel='similarity';
        case 'random27',c.video='C:/0819/4-25mvpp-luandong.avi';c.rois=[1201 686 50 75;1311 569 45 75;1053 821 58 110];c.referenceModel='similarity';
        case 'static13',c.video='C:/0819/2-5mvpp-static.avi';c.rois=[746 691 50 75;863 569 38 75;591 829 62 122];c.referenceModel='similarity';
        case 'static27',c.video='C:/0819/4-25mvpp-static.avi';c.rois=[697 696 50 75;819 578 38 70;535 839 62 130];c.referenceModel='similarity';
        case 'bridge',c.video='D:/07-26_single/man-qiao.avi';c.rois=[1153 335 51 85;935 386 102 175];
        otherwise,error('Unknown case');
    end
    c.output=fullfile(root,'outputs',tag,name);run_measurement(c);
end
end
