function masterTable = run_uav_experiments_selectable(userCfg,scenarioIds,algorithmNames)
%RUN_UAV_EXPERIMENTS_SELECTABLE 可选择环境、可恢复、多算法等 FE 实验入口。
%
% 核心保证
% -------------------------------------------------------------------------
% 1. 同一场景、同一 runID 的所有算法共享完全相同的环境和随机种子编号；
% 2. 所有算法使用相同 N 和 MaxFEs，仍按真实完整评价次数计数；
% 3. 环境每个场景只构建一次，DEM 和 B 样条缓存复用；
% 4. resume 只跳过元数据完全一致且 MAT/CSV 均存在的完成运行；
% 5. 每个输出目录冻结实验签名，禁止混合不同环境、预算或算法列表；
% 6. 并行仅发生在相互独立的 runID 层，不改变算法内部评价顺序。

if nargin < 1 || isempty(userCfg), userCfg = formal_experiment_config('formal'); end
if nargin < 2 || isempty(scenarioIds), scenarioIds = 1:6; end
if nargin < 3 || isempty(algorithmNames)
    algorithmNames = {'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'};
end
cfg = merge_structs(formal_experiment_config(cfg_profile(userCfg)),userCfg);
% 正式运行入口也执行一次防御性解析，避免调用者绕过
% run_selected_formal_experiment 时发生选择文件中途变化。
if strcmpi(cfg.environment.mode,'selected_library')
    [cfg,~,~] = resolve_environment_selection(cfg);
end
validate_config(cfg);
if any(~ismember(scenarioIds,1:6))
    error('run_uav_experiments_selectable:Scenario','scenarioIds must be from 1:6.');
end

root = cfg.experiment.outputDir;
if ~isfolder(root), mkdir(root); end
manifest = freeze_experiment_manifest(cfg,scenarioIds,algorithmNames);

numScenarios = numel(scenarioIds);
numRuns = cfg.experiment.numRuns;
numAlgorithms = numel(algorithmNames);
allRecords = cell(numScenarios,numRuns,numAlgorithms);
useParallel = prepare_parallel_mode(cfg);

for sIdx = 1:numScenarios
    sid = scenarioIds(sIdx);
    [baseEnv,candidateId] = build_experiment_environment(cfg,sid,100000+sid*1000);
    scenarioSeed = baseEnv.seed;
    fprintf('\n============================================================\n');
    fprintf('Scenario %s | candidate=%s | %s | realDEM=%d\n', ...
        baseEnv.id,candidateId,baseEnv.scenarioName, ...
        logical(safe_nested(baseEnv,{'meta','isRealDEM'},false)));
    fprintf('Profile=%s, runs=%d, N=%d, MaxFEs=%d, parallel=%d\n', ...
        cfg.experiment.profile,numRuns,cfg.algorithm.N,cfg.algorithm.MaxFEs,useParallel);
    fprintf('============================================================\n');

    for a = 1:numAlgorithms
        runDir = fullfile(root,sprintf('scenario_%s',baseEnv.id),sanitize(algorithmNames{a}));
        if ~isfolder(runDir), mkdir(runDir); end
    end

    scenarioRecords = cell(numRuns,numAlgorithms);
    if useParallel
        problemConstant = parallel.pool.Constant(@()make_problem(baseEnv,cfg));
        parfor runID = 1:numRuns
            problem = problemConstant.Value;
            scenarioRecords(runID,:) = execute_one_run(problem,cfg,algorithmNames, ...
                runID,scenarioSeed,root,manifest);
        end
        delete(problemConstant);
    else
        problem = make_problem(baseEnv,cfg);
        for runID = 1:numRuns
            scenarioRecords(runID,:) = execute_one_run(problem,cfg,algorithmNames, ...
                runID,scenarioSeed,root,manifest);
        end
    end
    allRecords(sIdx,:,:) = reshape(scenarioRecords,[1,numRuns,numAlgorithms]);

    if safe_field(cfg.experiment,'checkpointAfterScenario',true)
        partial = records_to_table(allRecords(1:sIdx,:,:));
        writetable(partial,fullfile(root,'master_results_partial.csv'));
    end
end

masterTable = records_to_table(allRecords);
writetable(masterTable,fullfile(root,'master_results.csv'));
summarize_results(root);
fprintf('\nExperiment completed or resumed successfully. Results: %s\n',root);
end

function records = execute_one_run(problem,cfg,algorithmNames,runID,scenarioSeed,root,manifest)
numAlgorithms = numel(algorithmNames);
records = cell(1,numAlgorithms);
sid = problem.env.scenarioId;
algorithmSeed = cfg.experiment.baseAlgorithmSeed + sid*1000 + runID;

for a = 1:numAlgorithms
    alg = algorithmNames{a};
    runCfg = cfg;
    runCfg.algorithm.seed = algorithmSeed;
    runDir = fullfile(root,sprintf('scenario_%s',problem.env.id),sanitize(alg));

    [canResume,existingRecord] = existing_run_record(runDir,alg,problem.env, ...
        runID,algorithmSeed,runCfg,manifest);
    if canResume
        fprintf('[resume] %s %s run=%03d seed=%d\n', ...
            problem.env.id,alg,runID,algorithmSeed);
        records{a} = existingRecord;
        continue;
    end

    fprintf('[run] %s candidate=%s alg=%s run=%03d/%03d seed=%d\n', ...
        problem.env.id,problem.env.candidateId,alg,runID, ...
        cfg.experiment.numRuns,algorithmSeed);
    try
        [best,bz,curve,out] = run_one_algorithm(alg,problem,runCfg);
        if safe_field(runCfg.experiment,'requireExactFEs',true)
            actualFEs = get_field(out,'actualFEs',NaN);
            if ~isfinite(actualFEs) || actualFEs ~= runCfg.algorithm.MaxFEs
                error('run_uav_experiments_selectable:UnequalFEs', ...
                    ['Algorithm %s reported actualFEs=%g, expected MaxFEs=%d. ', ...
                     'The run is rejected to preserve equal-FE comparison.'], ...
                    alg,actualFEs,runCfg.algorithm.MaxFEs);
            end
        end
        status = 'ok'; message = '';
    catch ME
        if cfg.experiment.failFast, rethrow(ME); end
        best = NaN; bz = []; curve = struct(); out = struct();
        status = 'error'; message = sprintf('%s: %s',ME.identifier,ME.message);
        warning('run_uav_experiments_selectable:RunFailed','%s',message);
    end

    record = make_record(alg,problem.env,runID,algorithmSeed,scenarioSeed, ...
        best,out,status,message,runCfg,problem.dim,manifest);
    savedEnv = problem.env;
    if safe_field(runCfg.experiment,'stripRuntimeCacheBeforeSave',true)
        savedEnv = strip_runtime_cache(savedEnv);
    end
    fullData = struct('cfg',runCfg,'env',savedEnv,'bestZ',bz, ...
        'curve',curve,'output',out, ...
        'experimentSignatureSHA256',manifest.signatureSHA256);
    save_run_result(runDir,record,fullData);
    records{a} = record;
end
end

function [tf,record] = existing_run_record(runDir,alg,env,runID,seed,cfg,manifest)
tf = false; record = struct();
if ~safe_field(cfg.experiment,'resume',true), return; end
base = sprintf('%s_%s_run%03d_seed%d',sanitize(alg),sanitize(env.id),runID,seed);
matFile = fullfile(runDir,[base '.mat']);
csvFile = fullfile(runDir,[base '.csv']);
if ~(isfile(matFile) && isfile(csvFile)), return; end
try
    d = load(matFile,'record');
    if ~isfield(d,'record'), return; end
    r = d.record;
    required = {'algorithm','scenario','runID','seed','N','MaxFEs', ...
        'candidateId','experimentSignatureSHA256','status'};
    for k=1:numel(required), if ~isfield(r,required{k}), return; end, end
    same = strcmpi(char(string(r.algorithm)),alg) && ...
        strcmpi(char(string(r.scenario)),env.id) && ...
        r.runID==runID && r.seed==seed && r.N==cfg.algorithm.N && ...
        r.MaxFEs==cfg.algorithm.MaxFEs && ...
        strcmpi(char(string(r.candidateId)),env.candidateId) && ...
        strcmpi(char(string(r.experimentSignatureSHA256)),manifest.signatureSHA256);
    if ~same
        if ~safe_field(cfg.experiment,'overwriteExisting',false)
            error('run_uav_experiments_selectable:ExistingMismatch', ...
                'Existing run metadata differs: %s',matFile);
        end
        return;
    end
    if strcmpi(char(string(r.status)),'error') && ...
            ~safe_field(cfg.experiment,'resumeErrorRuns',false)
        return;
    end
    record = r; tf = true;
catch ME
    if strcmp(ME.identifier,'run_uav_experiments_selectable:ExistingMismatch')
        rethrow(ME);
    end
    warning('run_uav_experiments_selectable:ResumeRead', ...
        'Cannot resume %s (%s); rerunning.',matFile,ME.message);
end
end

function useParallel = prepare_parallel_mode(cfg)
useParallel = logical(cfg.experiment.useParallel);
if ~useParallel, return; end
if ~license('test','Distrib_Computing_Toolbox') || isempty(ver('parallel'))
    warning('run_uav_experiments_selectable:ParallelUnavailable', ...
        'Parallel Computing Toolbox unavailable; using serial mode.');
    useParallel = false; return;
end
if safe_field(cfg.experiment,'autoStartParallelPool',true)
    try
        if isempty(gcp('nocreate')), parpool; end
    catch ME
        warning('run_uav_experiments_selectable:ParallelPool', ...
            'Cannot start pool (%s); using serial mode.',ME.message);
        useParallel = false;
    end
end
end

function [best,bz,curve,out] = run_one_algorithm(name,problem,cfg)
switch upper(strrep(name,'_','-'))
    case {'TAAS-FPO','TAAS'}
        [best,bz,curve,out] = TAAS_FPO(problem,cfg);
    case {'ASA-FPO','ASA'}
        [best,bz,curve,out] = ASA_FPO(problem,cfg);
    case {'FPO-N','N-FPO','NFPO'}
        [best,bz,curve,out] = N_FPO(problem,cfg);
    case 'PSO'
        [best,bz,curve,out] = PSO_constrained(problem,cfg);
    case 'DE'
        [best,bz,curve,out] = DE_constrained(problem,cfg);
    case 'GWO'
        [best,bz,curve,out] = GWO_constrained(problem,cfg);
    otherwise
        error('run_uav_experiments_selectable:Algorithm','Unknown algorithm: %s',name);
end
end

function r = make_record(alg,env,runID,seed,scenarioSeed,best,out,status,message,cfg,dim,manifest)
r = struct();
r.algorithm = string(alg);
r.scenario = string(env.id);
r.scenarioName = string(env.scenarioName);
r.candidateId = string(env.candidateId);
r.environmentMode = string(env.meta.environmentMode);
r.startGoalID = string(env.candidateId);
r.runID = runID; r.seed = seed; r.scenarioSeed = scenarioSeed;
r.status = string(status); r.message = string(message);
r.codeVersion = "1.3.0";
r.experimentProfile = string(cfg.experiment.profile);
r.experimentSignatureSHA256 = string(manifest.signatureSHA256);
r.N = cfg.algorithm.N; r.D = dim; r.MaxFEs = cfg.algorithm.MaxFEs;
r.bestCost = best;
if isfield(out,'bestResult') && ~isempty(out.bestResult)
    b=out.bestResult;
    r.isFeasible=b.isFeasible; r.bestCV=b.CV;
    r.length=get_cost(b,'length'); r.energy=get_cost(b,'energy');
    r.risk=get_cost(b,'risk'); r.smoothness=get_cost(b,'smoothness');
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
    r.maxClimbAngle=NaN; r.maxCurvature=NaN; r.maxAcceleration=NaN; r.maxAirSpeed=NaN;
end
r.firstFeasibleFE=get_field(out,'firstFeasibleFE',NaN);
r.actualFEs=get_field(out,'actualFEs',NaN);
r.numFullEvaluations=r.actualFEs;
r.runtime=get_field(out,'runtime',NaN);
r.MATLABVersion=string(version); r.computer=string(computer); r.gitCommit=get_git_commit();
r.isRealDEM=logical(safe_nested(env,{'meta','isRealDEM'},false));
r.DEMSource=string(safe_nested(env,{'terrain','description'},safe_nested(env,{'terrain','source'},'')));
r.DEMChecksum=string(safe_nested(env,{'terrain','sha256'},''));
r.DEMSourceTile=string(safe_nested(env,{'terrain','catalog','sourceTile'},safe_nested(env,{'meta','catalog','sourceTile'},'')));
r.DEMSourceSHA256=string(safe_nested(env,{'terrain','catalog','sourceSHA256'},''));
r.DEMCRS=string(safe_nested(env,{'terrain','crs'},safe_nested(env,{'terrain','catalog','crs'},'')));
resolution=safe_nested(env,{'terrain','resolution'},safe_nested(env,{'terrain','catalog','resolutionM'},[NaN NaN]));
if isscalar(resolution), resolution=[resolution resolution]; end
r.DEMResolutionX=resolution(1); r.DEMResolutionY=resolution(min(2,numel(resolution)));
r.DEMMissingFraction=safe_nested(env,{'terrain','missingFraction'},0);
end

function T=records_to_table(records)
flat = records(:);
flat = flat(~cellfun(@isempty,flat));
if isempty(flat)
    T = table();
    return;
end
% make_record 始终生成相同字段和字段顺序，因此可直接形成结构体数组。
% struct2table 会保留数值、logical 和 string 列的真实类型，便于即时分析；
% 相比 cell2table，不会把数值列暂时包装成 cell 列。
S = vertcat(flat{:});
T = struct2table(S);
T = T(:,record_names());
end
function n=record_names()
n={'algorithm','scenario','scenarioName','candidateId','environmentMode','startGoalID', ...
   'runID','seed','scenarioSeed','status','message','codeVersion','experimentProfile', ...
   'experimentSignatureSHA256','N','D','MaxFEs','bestCost','isFeasible','bestCV', ...
   'length','energy','risk','smoothness','flightTime','minClearance','minStaticDistance', ...
   'minDynamicDistance','maxClimbAngle','maxCurvature','maxAcceleration','maxAirSpeed', ...
   'firstFeasibleFE','actualFEs','numFullEvaluations','runtime','MATLABVersion','computer', ...
   'gitCommit','isRealDEM','DEMSource','DEMChecksum','DEMSourceTile','DEMSourceSHA256', ...
   'DEMCRS','DEMResolutionX','DEMResolutionY','DEMMissingFraction'};
end
function v=get_cost(b,name), if isfield(b,'cost')&&isfield(b.cost,name),v=b.cost.(name);else,v=NaN;end, end
function v=get_field(s,name,d), if isstruct(s)&&isfield(s,name),v=s.(name);else,v=d;end, end
function v=safe_field(s,name,d), if isstruct(s)&&isfield(s,name),v=s.(name);else,v=d;end, end
function v=safe_nested(s,path,d), v=d; for k=1:numel(path),if ~isstruct(s)||~isfield(s,path{k}),return;end,s=s.(path{k});end,v=s; end
function c=get_git_commit(), [status,txt]=system('git rev-parse --short HEAD');if status==0,c=string(strtrim(txt));else,c="unknown";end,end
function s=sanitize(x),s=regexprep(char(string(x)),'[^a-zA-Z0-9_-]','_');end
function p=cfg_profile(cfg),p='formal';if isfield(cfg,'experiment')&&isfield(cfg.experiment,'profile'),p=cfg.experiment.profile;end,end
