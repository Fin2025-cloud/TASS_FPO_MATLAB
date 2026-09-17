function T = run_robustness(userCfg,scenarioId)
%RUN_ROBUSTNESS Evaluate predefined DEM/wind/dynamic prediction perturbations.
%
% The unperturbed base scenario is loaded once. A perturbed environment is then
% generated for each condition and runID using a frozen perturbation seed. A new
% problem is required after perturbation because its terrain interpolant must
% correspond to the perturbed terrain. The original packaged DEM remains
% unchanged; perturb_environment operates on the in-memory environment copy.

if nargin<1 || isempty(userCfg), userCfg=default_config(); end
if nargin<2 || isempty(scenarioId), scenarioId=6; end
cfg=merge_structs(default_config(),userCfg);
validate_config(cfg);
numRuns=min(cfg.experiment.numRuns,15);

conditions={ ...
    'dem_noise',          {2,5}; ...
    'wind_scale',        {0.8,1.0,1.2}; ...
    'wind_direction_deg',{5,10,20}; ...
    'dynamic_noise',     {2,5,10}};

numLevels=sum(cellfun(@numel,conditions(:,2)));
rows=cell(numLevels*numRuns,10);
rowIndex=0;

scenarioSeed=100000+scenarioId*1000;
baseEnv=build_scenario_environment(cfg,scenarioId,scenarioSeed);

for conditionIndex=1:size(conditions,1)
    mode=conditions{conditionIndex,1};
    levels=conditions{conditionIndex,2};

    for levelIndex=1:numel(levels)
        level=levels{levelIndex};

        for runID=1:numRuns
            perturbationSeed=91000+10000*conditionIndex+100*levelIndex+runID;
            env=perturb_environment(baseEnv,mode,level,perturbationSeed);
            problem=make_problem(env,cfg);

            localCfg=cfg;
            localCfg.algorithm.seed=92000+scenarioId*1000+runID;
            [best,~,~,out]=TAAS_FPO(problem,localCfg);

            rowIndex=rowIndex+1;
            rows(rowIndex,:)={string(mode),level,runID,best, ...
                out.bestResult.CV,out.bestResult.isFeasible, ...
                out.bestResult.minClearance,out.bestResult.minDynamicDistance, ...
                out.firstFeasibleFE,out.runtime};
        end
    end
end

T=cell2table(rows,'VariableNames', ...
    {'Mode','Level','RunID','BestF','BestCV','Feasible', ...
     'MinClearance','MinDynamicDistance','FirstFeasibleFE','Runtime'});
outDir=fullfile(cfg.experiment.outputDir,'robustness');
if ~isfolder(outDir), mkdir(outDir); end
writetable(T,fullfile(outDir,sprintf('robustness_S%d.csv',scenarioId)));
end
