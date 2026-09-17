function test_environment_selection_freeze()
%TEST_ENVIRONMENT_SELECTION_FREEZE 检查正式配置会把六个候选固定在内存副本中。

cfg = formal_experiment_config('smoke');
ids = default_environment_selection();
cfg.environment.candidateIds = ids;
[cfg2,resolved,~] = resolve_environment_selection(cfg);
assert(isequal(string(resolved),string(ids)));
assert(isequal(string(cfg2.environment.candidateIds),string(ids)));

for s = 1:6
    [env,candidateId] = build_experiment_environment(cfg2,s,100000+s*1000);
    assert(strcmp(candidateId,ids{s}));
    assert(strcmp(env.candidateId,ids{s}));
end
fprintf('test_environment_selection_freeze passed.\n');
end
