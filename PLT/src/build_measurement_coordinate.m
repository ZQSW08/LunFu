function coordinate=build_measurement_coordinate(dTotal,dMacro)
% BUILD_MEASUREMENT_COORDINATE 只用整数宏观位移移动测量坐标。
% dCrop 对应报告 d_C=round(d_M)，residual 是留给细相位后端的余量。
dTotal=double(dTotal); dMacro=double(dMacro); dCrop=round(dMacro); residual=dTotal-dCrop;
coordinate=struct('dTotal',dTotal,'dMacro',dMacro,'dCrop',dCrop,'residual',residual,...
    'reconstructed',dCrop+residual,'usesImageWarp',false);
end
