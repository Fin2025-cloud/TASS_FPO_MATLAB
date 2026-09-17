function test_experiment_signature_guard()
%TEST_EXPERIMENT_SIGNATURE_GUARD 检查科学设置变化会被拒绝，运行设置可恢复。

cfg = formal_experiment_config('smoke');
cfg.environment.candidateIds = default_environment_selection();
tmp = tempname;
mkdir(tmp);
cleanup = onCleanup(@()rmdir(tmp,'s')); %#ok<NASGU>
cfg.experiment.outputDir = tmp;

first = freeze_experiment_manifest(cfg,1,{'TAAS-FPO'});
second = freeze_experiment_manifest(cfg,1,{'TAAS-FPO'});
assert(strcmp(first.signatureSHA256,second.signatureSHA256));

% 是否并行只改变执行方式，不改变数学问题，因此应允许同目录恢复。
cfgOperational = cfg;
cfgOperational.experiment.useParallel = ~cfg.experiment.useParallel;
third = freeze_experiment_manifest(cfgOperational,1,{'TAAS-FPO'});
assert(strcmp(first.signatureSHA256,third.signatureSHA256));

% MaxFEs 属于科学预算，必须拒绝混写。
cfgBudget = cfg;
cfgBudget.algorithm.MaxFEs = cfgBudget.algorithm.MaxFEs + 1;
failed = false;
try
    freeze_experiment_manifest(cfgBudget,1,{'TAAS-FPO'});
catch ME
    failed = strcmp(ME.identifier,'freeze_experiment_manifest:SignatureMismatch');
end
assert(failed,'Signature guard did not reject a changed evaluation budget.');

% 环境候选改变也必须拒绝混写。
C = environment_catalog();
alt = cfg;
idx = find([C.scenarioId]==1 & ~strcmp({C.id},cfg.environment.candidateIds{1}),1);
alt.environment.candidateIds{1} = C(idx).id;
failed = false;
try
    freeze_experiment_manifest(alt,1,{'TAAS-FPO'});
catch ME
    failed = strcmp(ME.identifier,'freeze_experiment_manifest:SignatureMismatch');
end
assert(failed,'Signature guard did not reject a changed environment candidate.');

fprintf('test_experiment_signature_guard passed.\n');
end
