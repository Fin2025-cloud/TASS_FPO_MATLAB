function test_bspline()
%TEST_BSPLINE 验证夹持 B 样条通过起终点且基函数分割统一。
cfg=default_config();cfg.path.K=6;cfg.path.M=101;cfg.path.enableAdaptiveSampling=false;
% [逐行说明] 计算或更新 `env`，供后续算法、评价或日志步骤使用。
env=build_synthetic_environment(cfg,1,123);problem=make_problem(env,cfg);
% [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
z=0.5*ones(1,problem.dim);p=problem.decode(z);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(norm(p.P(1,:)-env.start)<1e-9);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(norm(p.P(end,:)-env.goal)<1e-9);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(max(abs(sum(p.basis,2)-1))<1e-10);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(all(isfinite(p.P(:))));
end
