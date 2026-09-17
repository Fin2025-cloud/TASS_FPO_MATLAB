function test_fast_cache_equivalence()
%TEST_FAST_CACHE_EQUIVALENCE 验证缓存只加速、不改变评价定义。
cfg=default_config();
cfg.path.K=6;
cfg.path.M=100;
cfg.path.maxAdaptivePoints=180;
cfg.path.maxRefineRounds=2;
env=build_scenario_environment(cfg,3,103000);
problem=make_problem(env,cfg);
uncachedEnv=strip_runtime_cache(problem.env);

% 固定候选保证测试可重复，且不依赖优化器随机流。
state=rng; cleanup=onCleanup(@() rng(state)); %#ok<NASGU>
rng(424242,'twister');
z=0.15+0.70*rand(1,problem.dim);

cachedPath=problem.decode(z);
uncachedPath=decode_bspline_path(z,uncachedEnv,problem.cfg, ...
    problem.physicalLB,problem.physicalUB);
assert(isequal(cachedPath.basis,uncachedPath.basis), ...
    'Cached and uncached B-spline bases differ.');
assert(isequal(cachedPath.P,uncachedPath.P), ...
    'Cached and uncached decoded paths differ.');

xq=linspace(env.xLim(1)+1,env.xLim(2)-1,37)';
yq=linspace(env.yLim(2)-1,env.yLim(1)+1,37)';
hCached=terrain_height(problem.env,xq,yq);
hUncached=terrain_height(uncachedEnv,xq,yq);
assert(max(abs(hCached-hUncached))<=1e-9, ...
    'Cached terrain interpolation differs from interp2 reference.');

rCached=problem.evaluate(z);
rUncached=evaluate_path(z,uncachedEnv,problem.cfg, ...
    problem.physicalLB,problem.physicalUB);
assert(abs(rCached.F-rUncached.F)<=1e-8*max(1,abs(rUncached.F)), ...
    'Cached objective differs beyond tolerance.');
assert(abs(rCached.CV-rUncached.CV)<=1e-10*max(1,abs(rUncached.CV)), ...
    'Cached constraint violation differs beyond tolerance.');
assert(rCached.isFeasible==rUncached.isFeasible, ...
    'Cached and uncached feasibility flags differ.');
end
