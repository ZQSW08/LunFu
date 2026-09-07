function ok = test_coordinate_system()
%TEST_COORDINATE_SYSTEM 验证右/下平移和局部坐标仿射映射。
q=[3;4;0;0;0;0]; [x,y]=affine_warp(0,0,params_to_H(q));
assert(x==3 && y==4);
ok=true;
end
