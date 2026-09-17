function T = run_sensitivity(userCfg,scenarioId)
%RUN_SENSITIVITY Predefined one-factor sensitivity experiments.
%
% For each parameter value, the environment and problem are created once and
% reused across independent runID values. This is mathematically equivalent
% because only the optimizer random seed changes between those runs. Parameters
% that alter K or initialization behavior are applied before make_problem so the
% cached B-spline matrix and captured initializer configuration remain correct.

if nargin<1 || isempty(userCfg), userCfg=default_config(); end
if nargin<2 || isempty(scenarioId), scenarioId=3; end
cfg=merge_structs(default_config(),userCfg);
validate_config(cfg);

settings={ ...
    'K',           {8,10,12,16}; ...
    'seedFraction',{0.20,0.30,0.40}; ...
    'temperature', {0.10,0.20,0.40}; ...
    'pMinExp',     {0.04,0.08,0.12}; ...
    'repairRounds',{1,3,5}};

numRuns=min(10,cfg.experiment.numRuns);
numValues=sum(cellfun(@numel,settings(:,2)));
rows=cell(numValues*numRuns,8);
rowIndex=0;

scenarioSeed=100000+scenarioId*1000;
baseEnv=build_scenario_environment(cfg,scenarioId,scenarioSeed);

for settingIndex=1:size(settings,1)
    parameterName=settings{settingIndex,1};
    values=settings{settingIndex,2};

    for valueIndex=1:numel(values)
        value=values{valueIndex};
        localBase=cfg;

        switch parameterName
            case 'K'
                localBase.path.K=value;
            case 'seedFraction'
                localBase.initialization.seedFraction=value;
                remainingFraction=1-value;
                localBase.initialization.localTentFraction=0.64*remainingFraction;
                localBase.initialization.globalFraction=0.36*remainingFraction;
            case 'temperature'
                localBase.strategy.temperature=value;
            case 'pMinExp'
                localBase.strategy.pMinExploration=value;
            case 'repairRounds'
                localBase.repair.maxRounds=value;
            otherwise
                error('run_sensitivity:Parameter','Unknown parameter: %s',parameterName);
        end
        validate_config(localBase);

        % Rebuild once per parameter value because K and initializer settings can
        % legitimately change the cached path basis or problem-captured config.
        problem=make_problem(baseEnv,localBase);

        for runID=1:numRuns
            localCfg=localBase;
            localCfg.algorithm.seed=80000+10000*settingIndex+100*valueIndex+runID;
            [best,~,~,out]=TAAS_FPO(problem,localCfg);

            rowIndex=rowIndex+1;
            rows(rowIndex,:)={string(parameterName),value,runID,best, ...
                out.bestResult.CV,out.bestResult.isFeasible, ...
                out.firstFeasibleFE,out.runtime};
        end
    end
end

T=cell2table(rows,'VariableNames', ...
    {'Parameter','Value','RunID','BestF','BestCV','Feasible', ...
     'FirstFeasibleFE','Runtime'});
outDir=fullfile(cfg.experiment.outputDir,'sensitivity');
if ~isfolder(outDir), mkdir(outDir); end
writetable(T,fullfile(outDir,sprintf('sensitivity_S%d.csv',scenarioId)));
end
