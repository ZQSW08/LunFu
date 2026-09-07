function result=test_complex_interpolation()
% TEST_COMPLEX_INTERPOLATION 验证复响应插值不会把 wrapped phase 的边界平均到 0。
epsPhase=0.01; z=exp(1i*(pi-epsPhase))*ones(2,2); z(1,2)=exp(1i*(-pi+epsPhase)); z(2,1)=exp(1i*(-pi+epsPhase));
interpolated=interpolate_complex_response(z,1.5,1.5); angleValue=angle(interpolated); assert(abs(angleValue)>2.5,'complex interpolation test failed');
result=struct('interpolatedAngle',angleValue,'passed',true);
end
