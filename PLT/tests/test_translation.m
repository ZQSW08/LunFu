function result=test_translation(cfg)
% TEST_TRANSLATION 验证 POC 全局粗定位的整数偏移语义。
if nargin<1, cfg=default_config(pwd); end
rng(11,'twister'); template=rand(36,44); search=0.05*rand(140,180); topLeft=[53 37]; search(topLeft(2):topLeft(2)+size(template,1)-1,topLeft(1):topLeft(1)+size(template,2)-1)=template;
poc=global_poc_search(template,search,[]); errorPx=norm(poc.topLeft-topLeft); assert(errorPx<=2,'POC translation test failed');
result=struct('estimatedTopLeft',poc.topLeft,'trueTopLeft',topLeft,'errorPx',errorPx,'passed',true);
end
