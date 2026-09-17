function report = benchmark_evaluator_cache(scenarioId,numCandidates)
%BENCHMARK_EVALUATOR_CACHE 比较缓存前后评价器耗时并检查数值等价性。
%
% 本基准不改变正式配置，也不运行优化器。它用同一批固定候选分别调用：
%   cachedProblem.evaluate  - griddedInterpolant + 预计算 B 样条基矩阵；
%   evaluate_path           - 删除缓存后的原始 interp2/现场基矩阵路径。

if nargin<1 || isempty(scenarioId), scenarioId=3; end
if nargin<2 || isempty(numCandidates), numCandidates=40; end
startup();
cfg=default_config();
cfg.path.K=8;
cfg.path.M=240;
cfg.path.maxAdaptivePoints=500;
env=build_scenario_environment(cfg,scenarioId,100000+scenarioId*1000);
problem=make_problem(env,cfg);
uncachedEnv=strip_runtime_cache(problem.env);

state=rng; cleanup=onCleanup(@() rng(state)); %#ok<NASGU>
rng(20260724,'twister');
Z=rand(numCandidates,problem.dim);

cachedResult=cell(numCandidates,1);
uncachedResult=cell(numCandidates,1);
t=tic;
for i=1:numCandidates
    cachedResult{i}=problem.evaluate(Z(i,:));
end
cachedSeconds=toc(t);
t=tic;
for i=1:numCandidates
    uncachedResult{i}=evaluate_path(Z(i,:),uncachedEnv,problem.cfg, ...
        problem.physicalLB,problem.physicalUB);
end
uncachedSeconds=toc(t);

maxFDifference=0; maxCVDifference=0; feasibleEqual=true;
for i=1:numCandidates
    maxFDifference=max(maxFDifference,abs(cachedResult{i}.F-uncachedResult{i}.F));
    maxCVDifference=max(maxCVDifference,abs(cachedResult{i}.CV-uncachedResult{i}.CV));
    feasibleEqual=feasibleEqual && cachedResult{i}.isFeasible==uncachedResult{i}.isFeasible;
end
report=table(string(env.id),numCandidates,cachedSeconds,uncachedSeconds, ...
    uncachedSeconds/max(cachedSeconds,eps),maxFDifference,maxCVDifference,feasibleEqual, ...
    'VariableNames',{'Scenario','Candidates','CachedSeconds','UncachedSeconds', ...
    'Speedup','MaxAbsFDifference','MaxAbsCVDifference','FeasibleFlagsEqual'});
disp(report);
end
