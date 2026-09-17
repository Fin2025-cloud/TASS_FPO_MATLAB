function test_dynamic_collision()
%TEST_DYNAMIC_COLLISION 验证区间相对运动能发现离散端点之间的交叉。
cfg=default_config();
% [逐行说明] 计算或更新 `env`，供后续算法、评价或日志步骤使用。
env=build_synthetic_environment(cfg,1,11);
% [逐行说明] 计算或更新 `env.dynamicObstacles`，供后续算法、评价或日志步骤使用。
env.dynamicObstacles=struct('p0',[5,-5,0],'velocity',[0,10,0],'radius',0.1, ...
    'sigma0',0,'sigmaRate',0,'name','crossing');
% [逐行说明] 计算或更新 `cfg.uav.radius`，供后续算法、评价或日志步骤使用。
cfg.uav.radius=0.1;cfg.constraint.dynamicSafety=0.1;cfg.constraint.robustEta=0;
% [逐行说明] 计算或更新 `P`，供后续算法、评价或日志步骤使用。
P=[0,0,0;10,0,0];time=[0;1];
% [逐行说明] 计算或更新 `out`，供后续算法、评价或日志步骤使用。
out=dynamic_obstacle_check(P,time,env,cfg);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(out.maxDeficit>0,'Crossing collision was not detected.');
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(abs(out.worstTime-0.5)<1e-6);
end
