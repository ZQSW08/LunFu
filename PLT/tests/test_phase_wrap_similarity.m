function result=test_phase_wrap_similarity()
% TEST_PHASE_WRAP_SIMILARITY 验证 +pi/-pi 相邻相位不会被误判为相差 2pi。
epsPhase=0.01; z0=exp(1i*(pi-epsPhase)); z1=exp(1i*(-pi+epsPhase)); [score,coherence,meanPhase]=phase_circular_similarity(z0,z1,1);
assert(score>0.99 && coherence>0.99,'circular phase wrap test failed');
result=struct('score',score,'coherence',coherence,'meanPhase',meanPhase,'passed',true);
end
