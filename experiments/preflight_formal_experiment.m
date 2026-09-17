function report = preflight_formal_experiment(cfg,scenarioIds,algorithmNames)
%PREFLIGHT_FORMAL_EXPERIMENT 快速检查正式实验，不调用任何优化器。
%
% 检查：配置、环境选择、公开 DEM 摘要、30 m 栅格缓存、起终点净空、
% 统一问题接口和一次确定性路径评价。该函数不会产生论文算法结果。

if nargin < 1 || isempty(cfg), cfg = formal_experiment_config('formal'); end
if nargin < 2 || isempty(scenarioIds), scenarioIds = 1:6; end
if nargin < 3 || isempty(algorithmNames)
    algorithmNames = {'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'};
end
% 防御性冻结候选编号；预检与随后正式运行必须引用同一 cfg 副本。
if strcmpi(cfg.environment.mode,'selected_library')
    [cfg,~,~] = resolve_environment_selection(cfg);
end
validate_config(cfg);
validate_formal_budget(cfg);

if strcmpi(cfg.environment.mode,'selected_library') && cfg.data.verifyChecksum
    verify_real_dem_library();
elseif strcmpi(cfg.environment.mode,'featured_v111') && cfg.data.verifyChecksum
    verify_packaged_dem_integrity();
end

rows = cell(numel(scenarioIds),11);
for i = 1:numel(scenarioIds)
    sid = scenarioIds(i);
    [env,candidateId] = build_experiment_environment(cfg,sid,100000+sid*1000);
    problem = make_problem(env,cfg);

    % 中心决策向量只用于验证评价器可调用，不作为算法或论文结果。
    result = problem.evaluate(0.5*ones(1,problem.dim));
    hs = terrain_height(env,env.start(1),env.start(2));
    hg = terrain_height(env,env.goal(1),env.goal(2));
    relief = max(env.terrain.Z(:))-min(env.terrain.Z(:));
    isReal = logical(safe_nested(env,{'meta','isRealDEM'},false));
    rows(i,:) = {sid,string(candidateId),string(env.scenarioName),isReal, ...
        relief,env.start(3)-hs,env.goal(3)-hg,problem.dim, ...
        logical(result.isFeasible),result.F,result.CV};
end
report = cell2table(rows,'VariableNames', ...
    {'Scenario','CandidateId','ScenarioName','IsRealDEM','Relief_m', ...
     'StartAGL_m','GoalAGL_m','DecisionDimension','ProbeFeasible','ProbeF','ProbeCV'});
disp(report);
fprintf('Preflight passed. Optimizer calls: 0. Algorithms requested: %s\n', ...
    strjoin(cellstr(string(algorithmNames)),', '));
end

function validate_formal_budget(cfg)
if isfield(cfg.experiment,'assertFormalBudget') && cfg.experiment.assertFormalBudget
    expected = [cfg.path.K,cfg.path.M,cfg.algorithm.N,cfg.algorithm.MaxFEs,cfg.experiment.numRuns];
    if ~isequal(expected,[12,400,60,50000,30])
        error('preflight_formal_experiment:FormalBudget', ...
            ['profile=formal 但 K/M/N/MaxFEs/runs 不是 ', ...
             '12/400/60/50000/30。请使用新的输出目录并明确记录修改。']);
    end
end
end
function value=safe_nested(s,path,defaultValue)
value=defaultValue;
for k=1:numel(path)
    if ~isstruct(s)||~isfield(s,path{k}),return;end
    s=s.(path{k});
end
value=s;
end
