function masterTable = run_uav_experiments(userCfg,scenarioIds,algorithmNames)
%RUN_UAV_EXPERIMENTS 六场景、多算法、等 FE、可复现正式实验入口。
%
% 与 v1.0.3 相比的等价加速
% -------------------------------------------------------------------------
% 1. 每个 scenario 只加载/构造一次固定环境，所有算法与 runID 共享同一环境；
% 2. 串行模式下 problem 和运行时缓存每个场景只构造一次；
% 3. 可选并行模式只并行相互独立的 runID，每个 runID 使用冻结随机种子；
% 4. 结果表预分配，不再使用 rows(end+1,:) 动态扩容；
% 5. 保存前删除可确定性重建的插值器和样条缓存，DEM 与结果数据不变。
%
% 公平性与真实性
% -------------------------------------------------------------------------
% 同一场景、同一 runID 下所有算法使用相同算法种子、起终点、DEM、风场和
% 障碍轨迹；种群规模 N 与 MaxFEs 完全一致。并行只改变任务调度，不改变
% 单个算法内部候选评价顺序或 FE 定义。

if nargin<1 || isempty(userCfg), userCfg=default_config(); end
if nargin<2 || isempty(scenarioIds), scenarioIds=1:6; end
if nargin<3 || isempty(algorithmNames)
    algorithmNames={'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'};
end
cfg=merge_structs(default_config(),userCfg);
validate_config(cfg);

if any(~ismember(scenarioIds,1:6))
    error('run_uav_experiments:Scenario','scenarioIds must be selected from 1:6.');
end
root=cfg.experiment.outputDir;
if ~isfolder(root), mkdir(root); end

numScenarios=numel(scenarioIds);
numRuns=cfg.experiment.numRuns;
numAlgorithms=numel(algorithmNames);
allRecords=cell(numScenarios,numRuns,numAlgorithms);

useParallel=prepare_parallel_mode(cfg);
for sIdx=1:numScenarios
    sid=scenarioIds(sIdx);
    % 六个场景是论文中冻结的问题实例，因此环境种子只由 scenarioId 决定，
    % 不随 runID 改变；统计重复只改变优化算法随机流。
    scenarioSeed=100000+sid*1000;
    baseEnv=build_scenario_environment(cfg,sid,scenarioSeed);
    fprintf('\n============================================================\n');
    fprintf('Scenario %s: %s | realDEM=%d\n', ...
        baseEnv.id,baseEnv.scenarioName,logical(baseEnv.meta.isRealDEM));
    fprintf('============================================================\n');

    % 在进入 parfor 前串行创建目录，避免多个工作进程同时 mkdir。
    for a=1:numAlgorithms
        runDir=fullfile(root,sprintf('scenario_%s',baseEnv.id),sanitize(algorithmNames{a}));
        if ~isfolder(runDir), mkdir(runDir); end
    end
    scenarioRecords=cell(numRuns,numAlgorithms);
    if useParallel
        % 每个工作进程只创建一次 problem。parallel.pool.Constant 避免在每个
        % runID 中重复建立 griddedInterpolant 和 B 样条基矩阵，也避免把大型
        % 环境结构在每次迭代中重复传输。它只缓存只读对象，不改变随机流、
        % 候选顺序、函数评价次数或算法公式。
        problemConstant=parallel.pool.Constant(@() make_problem(baseEnv,cfg));
        % 每个 parfor 迭代负责一个完整 runID，并在该工作进程中依次运行全部
        % 算法。这样同一 runID 的算法共享环境，且不会嵌套并行或改变算法内部
        % 的随机调用顺序。
        parfor runID=1:numRuns
            problem=problemConstant.Value;
            scenarioRecords(runID,:)=execute_one_run( ...
                problem,cfg,algorithmNames,runID,scenarioSeed,root);
        end
        delete(problemConstant);
        clear problemConstant;
    else
        % 串行模式下缓存对象只创建一次，这是默认且最容易逐位复核的模式。
        problem=make_problem(baseEnv,cfg);
        for runID=1:numRuns
            scenarioRecords(runID,:)=execute_one_run( ...
                problem,cfg,algorithmNames,runID,scenarioSeed,root);
        end
    end
    allRecords(sIdx,:,:)=reshape(scenarioRecords,[1,numRuns,numAlgorithms]);
end

rows=cell(numScenarios*numRuns*numAlgorithms,numel(record_names()));
rowIndex=0;
for sIdx=1:numScenarios
    for runID=1:numRuns
        for a=1:numAlgorithms
            rowIndex=rowIndex+1;
            rows(rowIndex,:)=struct2row(allRecords{sIdx,runID,a});
        end
    end
end
masterTable=cell2table(rows,'VariableNames',record_names());
writetable(masterTable,fullfile(root,'master_results.csv'));
summarize_results(root);
end

function records=execute_one_run(problem,cfg,algorithmNames,runID,scenarioSeed,root)
%EXECUTE_ONE_RUN 在同一问题和随机种子规则下运行全部比较算法。
numAlgorithms=numel(algorithmNames);
records=cell(1,numAlgorithms);
algorithmSeed=200000+str2double(problem.env.id(2:end))*1000+runID;

for a=1:numAlgorithms
    alg=algorithmNames{a};
    runCfg=cfg;
    runCfg.algorithm.seed=algorithmSeed;
    fprintf('[%s] scenario=%s run=%d/%d seed=%d\n', ...
        alg,problem.env.id,runID,cfg.experiment.numRuns,algorithmSeed);
    try
        [best,bz,curve,out]=run_one_algorithm(alg,problem,runCfg);
        status='ok';
        message='';
    catch ME
        if cfg.experiment.failFast, rethrow(ME); end
        best=NaN; bz=[]; curve=struct(); out=struct();
        status='error';
        message=sprintf('%s: %s',ME.identifier,ME.message);
        warning('run_uav_experiments:RunFailed','%s',message);
    end

    record=make_record(alg,problem.env,runID,algorithmSeed,scenarioSeed, ...
        best,out,status,message,runCfg,problem.dim);
    runDir=fullfile(root,sprintf('scenario_%s',problem.env.id),sanitize(alg));
    savedEnv=problem.env;
    if safe_field(runCfg.experiment,'stripRuntimeCacheBeforeSave',true)
        savedEnv=strip_runtime_cache(savedEnv);
    end
    fullData=struct('cfg',runCfg,'env',savedEnv,'bestZ',bz, ...
        'curve',curve,'output',out);
    save_run_result(runDir,record,fullData);
    records{a}=record;
end
end

function useParallel=prepare_parallel_mode(cfg)
%PREPARE_PARALLEL_MODE 检查并行工具箱，失败时明确回退到串行。
useParallel=logical(cfg.experiment.useParallel);
if ~useParallel, return; end
if ~license('test','Distrib_Computing_Toolbox') || isempty(ver('parallel'))
    warning('run_uav_experiments:ParallelUnavailable', ...
        'Parallel Computing Toolbox is unavailable; using serial mode.');
    useParallel=false;
    return;
end
if safe_field(cfg.experiment,'autoStartParallelPool',true)
    try
        if isempty(gcp('nocreate')), parpool; end
    catch ME
        warning('run_uav_experiments:ParallelPool', ...
            'Cannot start parallel pool (%s); using serial mode.',ME.message);
        useParallel=false;
    end
end
end

function [best,bz,curve,out]=run_one_algorithm(name,problem,cfg)
switch upper(strrep(name,'_','-'))
    case {'TAAS-FPO','TAAS'}
        [best,bz,curve,out]=TAAS_FPO(problem,cfg);
    case {'ASA-FPO','ASA'}
        [best,bz,curve,out]=ASA_FPO(problem,cfg);
    case {'FPO-N','N-FPO','NFPO'}
        [best,bz,curve,out]=N_FPO(problem,cfg);
    case 'PSO'
        [best,bz,curve,out]=PSO_constrained(problem,cfg);
    case 'DE'
        [best,bz,curve,out]=DE_constrained(problem,cfg);
    case 'GWO'
        [best,bz,curve,out]=GWO_constrained(problem,cfg);
    otherwise
        error('run_uav_experiments:Algorithm','Unknown algorithm: %s',name);
end
end

function r=make_record(alg,env,runID,seed,scenarioSeed,best,out,status,message,cfg,dim)
r=struct();
r.algorithm=string(alg);
r.scenario=string(env.id);
r.scenarioName=string(env.scenarioName);
r.startGoalID="default";
r.runID=runID;
r.seed=seed;
r.scenarioSeed=scenarioSeed;
r.status=string(status);
r.message=string(message);
r.codeVersion="1.1.1";
r.N=cfg.algorithm.N;
r.D=dim;
r.MaxFEs=cfg.algorithm.MaxFEs;
r.bestCost=best;
if isfield(out,'bestResult') && ~isempty(out.bestResult)
    b=out.bestResult;
    r.isFeasible=b.isFeasible;
    r.bestCV=b.CV;
    r.length=get_cost(b,'length');
    r.energy=get_cost(b,'energy');
    r.risk=get_cost(b,'risk');
    r.smoothness=get_cost(b,'smoothness');
    r.flightTime=get_cost(b,'time');
    r.minClearance=get_field(b,'minClearance',NaN);
    r.minStaticDistance=get_field(b,'minStaticDistance',NaN);
    r.minDynamicDistance=get_field(b,'minDynamicDistance',NaN);
    r.maxClimbAngle=get_field(b,'maxClimbAngle',NaN);
    r.maxCurvature=get_field(b,'maxCurvature',NaN);
    r.maxAcceleration=get_field(b,'maxAcceleration',NaN);
    r.maxAirSpeed=get_field(b,'maxAirSpeed',NaN);
else
    r.isFeasible=false; r.bestCV=NaN; r.length=NaN; r.energy=NaN;
    r.risk=NaN; r.smoothness=NaN; r.flightTime=NaN;
    r.minClearance=NaN; r.minStaticDistance=NaN; r.minDynamicDistance=NaN;
    r.maxClimbAngle=NaN; r.maxCurvature=NaN;
    r.maxAcceleration=NaN; r.maxAirSpeed=NaN;
end
r.firstFeasibleFE=get_field(out,'firstFeasibleFE',NaN);
r.actualFEs=get_field(out,'actualFEs',NaN);
r.numFullEvaluations=r.actualFEs;
r.runtime=get_field(out,'runtime',NaN);
r.MATLABVersion=string(version);
r.computer=string(computer);
r.gitCommit=get_git_commit();
r.isRealDEM=logical(get_nested(env,{'meta','isRealDEM'},false));
r.DEMSource=string(get_nested(env,{'terrain','description'},''));
r.DEMChecksum=string(get_nested(env,{'terrain','sha256'},''));
r.DEMSourceTile=string(get_nested(env,{'meta','catalog','sourceTile'},''));
r.DEMSourceSHA256=string(get_nested(env,{'meta','catalog','sourceSHA256'},''));
r.DEMCRS=string(get_nested(env,{'terrain','crs'},''));
resolution=get_nested(env,{'terrain','resolution'},[NaN NaN]);
r.DEMResolutionX=resolution(1);
r.DEMResolutionY=resolution(min(2,numel(resolution)));
r.DEMMissingFraction=get_nested(env,{'terrain','missingFraction'},0);
end

function value=get_nested(s,path,defaultValue)
value=defaultValue;
for k=1:numel(path)
    if ~isstruct(s) || ~isfield(s,path{k}), return; end
    s=s.(path{k});
end
value=s;
end
function v=get_cost(b,name)
if isfield(b,'cost') && isfield(b.cost,name), v=b.cost.(name); else, v=NaN; end
end
function v=get_field(s,name,d)
if isstruct(s) && isfield(s,name), v=s.(name); else, v=d; end
end
function c=struct2row(r)
n=record_names(); c=cell(1,numel(n));
for i=1:numel(n), c{i}=r.(n{i}); end
end
function n=record_names()
n={'algorithm','scenario','scenarioName','startGoalID','runID','seed','scenarioSeed','status','message', ...
   'codeVersion','N','D','MaxFEs','bestCost','isFeasible','bestCV','length','energy','risk','smoothness','flightTime', ...
   'minClearance','minStaticDistance','minDynamicDistance','maxClimbAngle','maxCurvature','maxAcceleration','maxAirSpeed', ...
   'firstFeasibleFE','actualFEs','numFullEvaluations','runtime','MATLABVersion','computer','gitCommit', ...
   'isRealDEM','DEMSource','DEMChecksum','DEMSourceTile','DEMSourceSHA256','DEMCRS', ...
   'DEMResolutionX','DEMResolutionY','DEMMissingFraction'};
end
function c=get_git_commit()
[status,txt]=system('git rev-parse --short HEAD');
if status==0, c=string(strtrim(txt)); else, c="unknown"; end
end
function s=sanitize(x)
s=regexprep(char(string(x)),'[^a-zA-Z0-9_-]','_');
end
