function T = run_ablation(userCfg,scenarioId)
%RUN_ABLATION Run six predefined module combinations on one frozen scene.
%
% All variants share the same environment, N, MaxFEs and runID seed. A separate
% problem is created once for each variant because problem.initializer captures
% problem.cfg; this ensures that disabling TAI in a variant also disables it in
% the initializer itself. The problem is then reused across all independent runs
% of that variant, avoiding repeated DEM loading and cache construction.
%
% Variants
% -------------------------------------------------------------------------
% N-FPO          numerical stabilization only; no TAI/ASA/CDR;
% FPO+TAI        terrain-aware initialization only;
% FPO+ASA        adaptive strategy/stagnation components only;
% FPO+CDR        constraint-driven repair only;
% FPO+ASA+CDR    no terrain-aware initialization;
% TAAS-FPO       complete system.

if nargin<1 || isempty(userCfg), userCfg=default_config(); end
if nargin<2 || isempty(scenarioId), scenarioId=3; end
cfg=merge_structs(default_config(),userCfg);
validate_config(cfg);

variants={ ...
    'N-FPO',       struct('initialization',struct('enabled',false),'strategy',struct('enabled',false),'repair',struct('enabled',false),'stagnation',struct('enabled',false)); ...
    'FPO+TAI',     struct('initialization',struct('enabled',true),'strategy',struct('enabled',false),'repair',struct('enabled',false),'stagnation',struct('enabled',false)); ...
    'FPO+ASA',     struct('initialization',struct('enabled',false),'strategy',struct('enabled',true),'repair',struct('enabled',false),'stagnation',struct('enabled',true)); ...
    'FPO+CDR',     struct('initialization',struct('enabled',false),'strategy',struct('enabled',false),'repair',struct('enabled',true),'stagnation',struct('enabled',false)); ...
    'FPO+ASA+CDR', struct('initialization',struct('enabled',false),'strategy',struct('enabled',true),'repair',struct('enabled',true),'stagnation',struct('enabled',true)); ...
    'TAAS-FPO',    struct('initialization',struct('enabled',true),'strategy',struct('enabled',true),'repair',struct('enabled',true),'stagnation',struct('enabled',true))};

numVariants=size(variants,1);
numRuns=cfg.experiment.numRuns;
rows=cell(numVariants*numRuns,8);
rowIndex=0;

% The scenario is a frozen paper instance. Repeated statistical runs change only
% the optimization random stream, not terrain, start/goal, wind or obstacles.
scenarioSeed=100000+scenarioId*1000;
baseEnv=build_scenario_environment(cfg,scenarioId,scenarioSeed);

for variantIndex=1:numVariants
    variantName=variants{variantIndex,1};
    variantCfg=merge_structs(cfg,variants{variantIndex,2});

    % make_problem must see variantCfg so its initializer captures the correct
    % module switches. DEM/interpolant/B-spline objects are built only once for
    % this variant and reused across runID values.
    problem=make_problem(baseEnv,variantCfg);

    for runID=1:numRuns
        localCfg=variantCfg;
        localCfg.algorithm.seed=60000+scenarioId*1000+runID;
        [best,~,~,out]=TAAS_FPO(problem,localCfg);

        rowIndex=rowIndex+1;
        rows(rowIndex,:)={string(variantName),runID,best, ...
            out.bestResult.CV,out.bestResult.isFeasible, ...
            out.firstFeasibleFE,out.actualFEs,out.runtime};
    end
end

T=cell2table(rows,'VariableNames', ...
    {'Variant','RunID','BestF','BestCV','Feasible', ...
     'FirstFeasibleFE','FEs','Runtime'});
outDir=fullfile(cfg.experiment.outputDir,'ablation');
if ~isfolder(outDir), mkdir(outDir); end
writetable(T,fullfile(outDir,sprintf('ablation_S%d.csv',scenarioId)));
end
