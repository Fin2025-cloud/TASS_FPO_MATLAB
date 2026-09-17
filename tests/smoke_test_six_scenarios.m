function report = smoke_test_six_scenarios()
%SMOKE_TEST_SIX_SCENARIOS Build and evaluate one deterministic path per scene.
%
% Purpose
% -------------------------------------------------------------------------
% This is a fast integration check, not a performance experiment. It verifies
% that all six environment definitions can be loaded, converted into the common
% problem interface and evaluated once without invoking an optimizer.
%
% The same normalized control-point vector is used in every scenario. It is not
% expected to be feasible in every difficult scene; infeasibility is a valid
% output because this script checks execution integrity rather than solution
% quality.
%
% Usage
% -------------------------------------------------------------------------
%   startup;
%   report = smoke_test_six_scenarios;

startup();
cfg = default_config();

% Use a moderate path representation so the check finishes quickly while still
% exercising B-spline decoding, adaptive terrain sampling, collision checking,
% wind, dynamics and energy evaluation.
cfg.path.K = 8;
cfg.path.M = 180;
cfg.path.maxAdaptivePoints = 420;
cfg.path.maxRefineRounds = 3;

scenario = strings(6,1);
scenarioName = strings(6,1);
isRealDEM = false(6,1);
objective = nan(6,1);
constraintViolation = nan(6,1);
isFeasible = false(6,1);
minClearanceM = nan(6,1);
terrainCells = nan(6,1);
demSHA256 = strings(6,1);
runtimeSeconds = nan(6,1);

for sid = 1:6
    timerHandle = tic;
    env = build_scenario_environment(cfg,sid,100000+sid*1000);
    problem = make_problem(env,cfg);

    % Internal control points are placed along the start-goal direction in x/y.
    % Their normalized z coordinate is fixed at 0.65, which is intentionally not
    % repaired or tuned from the result. This keeps the check deterministic.
    fractions = linspace(0,1,cfg.path.K+2)';
    internal = fractions(2:end-1);
    startNormalized = (env.start-[env.xLim(1),env.yLim(1),env.zLim(1)]) ./ ...
        [diff(env.xLim),diff(env.yLim),diff(env.zLim)];
    goalNormalized = (env.goal-[env.xLim(1),env.yLim(1),env.zLim(1)]) ./ ...
        [diff(env.xLim),diff(env.yLim),diff(env.zLim)];
    z = zeros(1,problem.dim);
    for k = 1:cfg.path.K
        base = 3*(k-1);
        pointNormalized = startNormalized + internal(k)*(goalNormalized-startNormalized);
        z(base+1:base+3) = min(1,max(0,pointNormalized));
    end
    result = problem.evaluate(z);

    scenario(sid) = string(env.id);
    scenarioName(sid) = string(env.scenarioName);
    isRealDEM(sid) = logical(env.meta.isRealDEM);
    objective(sid) = result.F;
    constraintViolation(sid) = result.CV;
    isFeasible(sid) = result.isFeasible;
    minClearanceM(sid) = result.minClearance;
    terrainCells(sid) = numel(env.terrain.Z);
    if env.meta.isRealDEM
        demSHA256(sid) = string(env.terrain.sha256);
    else
        demSHA256(sid) = "synthetic";
    end
    runtimeSeconds(sid) = toc(timerHandle);
end

report = table(scenario,scenarioName,isRealDEM,objective, ...
    constraintViolation,isFeasible,minClearanceM,terrainCells, ...
    demSHA256,runtimeSeconds, ...
    'VariableNames',{'Scenario','ScenarioName','IsRealDEM','Objective', ...
    'ConstraintViolation','IsFeasible','MinClearanceM','TerrainCells', ...
    'DEMSHA256','RuntimeSeconds'});
disp(report);
end
