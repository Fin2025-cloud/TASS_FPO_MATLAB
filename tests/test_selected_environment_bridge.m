function test_selected_environment_bridge()
%TEST_SELECTED_ENVIRONMENT_BRIDGE 验证候选环境可进入 v1.1.1 统一评价接口。
cfg=formal_experiment_config('smoke');
ids=default_environment_selection();
cfg.environment.candidateIds=ids;
for s=1:6
    [env,candidateId]=build_experiment_environment(cfg,s,100000+s*1000);
    assert(strcmp(candidateId,ids{s}));
    assert(strcmp(env.id,sprintf('S%d',s)));
    problem=make_problem(env,cfg);
    result=problem.evaluate(.5*ones(1,problem.dim));
    assert(isfield(result,'F')&&isfield(result,'CV')&&isfield(result,'isFeasible'));
end
fprintf('test_selected_environment_bridge passed.\n');
end
