function output = run_quick_comparison(options)
%RUN_QUICK_COMPARISON 对已保存环境执行低预算多算法对比并自动绘图。
%
% 该函数用于连通性检查、环境筛选和初步路径观察，不作为论文正式统计。
% 正式实验请使用 FPO_LAB -> 正式实验。
%
% 示例：
%   opts = struct('scenarioNumbers',[2 3], ...
%       'algorithmNames',{{'TAAS-FPO','ASA-FPO','PSO'}}, ...
%       'profile','quick','numRuns',1);
%   out = run_quick_comparison(opts);
%
% options 可选字段：
%   scenarioNumbers       场景编号，默认 [2 3]
%   algorithmNames        算法列表，默认 TAAS-FPO/ASA-FPO/PSO
%   profile               smoke、quick 或 balanced
%   numRuns               每种算法运行次数，默认 1
%   baseSeed              基础随机种子
%   showPathFigures       是否显示路径图
%   showConvergenceFigures 是否显示收敛图
%   saveResults           是否保存 CSV/MAT
%   saveFigures           是否保存 PNG
%   outputDir             自定义结果目录；空值时使用时间戳目录

if nargin < 1 || isempty(options), options = struct(); end
scenarioNumbers = read_option(options,'scenarioNumbers',[2 3]);
algorithmNames = read_option(options,'algorithmNames', ...
    {'TAAS-FPO','ASA-FPO','PSO'});
testProfile = char(read_option(options,'profile','quick'));
numRuns = read_option(options,'numRuns',1);
baseSeed = read_option(options,'baseSeed',20260727);
showPathFigures = logical(read_option(options,'showPathFigures',true));
showConvergenceFigures = logical(read_option(options, ...
    'showConvergenceFigures',true));
saveResults = logical(read_option(options,'saveResults',true));
saveFigures = logical(read_option(options,'saveFigures',true));

%% 2. 初始化工程并读取选项5保存的环境
startup;
fprintf('Running script file: %s\n',mfilename('fullpath'));
projectRoot = project_root();
cfg = environment_config();

selectionFile = fullfile(projectRoot,cfg.environment.selectionFile);
if ~isfile(selectionFile)
    error(['没有找到已保存的环境组合：\n%s\n' ...
        '请运行 FPO_LAB，在“环境管理”中保存六个环境。'], ...
        selectionFile);
end

loaded = load(selectionFile,'selection');
if ~isfield(loaded,'selection') || ...
        ~isfield(loaded.selection,'candidateIds') || ...
        numel(loaded.selection.candidateIds) ~= 6
    error('selected_environments.mat 中的 selection.candidateIds 格式不正确。');
end

candidateIds = loaded.selection.candidateIds;
if isstring(candidateIds)
    candidateIds = cellstr(candidateIds);
end
candidateIds = reshape(candidateIds,1,[]);

scenarioNumbers = unique(scenarioNumbers(:)','stable');
if isempty(scenarioNumbers) || any(~ismember(scenarioNumbers,1:6))
    error('scenarioNumbers 必须由 1~6 的场景编号组成。');
end
if isempty(algorithmNames)
    error('algorithmNames 不能为空。');
end
if ischar(algorithmNames)
    algorithmNames = {algorithmNames};
elseif isstring(algorithmNames)
    algorithmNames = cellstr(algorithmNames);
end

%% 3. 应用快速测试规模
cfg = apply_test_profile(cfg,testProfile);
cfg.algorithm.verbose = false;
cfg.algorithm.assertInvariants = false;
cfg.algorithm.logEveryFE = max(1,round(cfg.algorithm.MaxFEs/30));
cfg.stagnation.cooldownFEs = 3*cfg.algorithm.N;

fprintf('\n============================================================\n');
fprintf('Selected-environment quick comparison\n');
fprintf('Profile     : %s\n',testProfile);
fprintf('Scenarios   : %s\n',mat2str(scenarioNumbers));
fprintf('Algorithms  : %s\n',strjoin(algorithmNames,', '));
fprintf('Runs        : %d\n',numRuns);
fprintf('N / MaxFEs  : %d / %d\n',cfg.algorithm.N,cfg.algorithm.MaxFEs);
fprintf('K / M       : %d / %d\n',cfg.path.K,cfg.path.M);
fprintf('============================================================\n\n');

%% 4. 准备保存目录
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
resultDir = read_option(options,'outputDir','');
if isempty(resultDir)
    resultDir = fullfile(projectRoot,'results','quick_algorithm_comparison',stamp);
end
if saveResults || saveFigures
    if ~isfolder(resultDir)
        mkdir(resultDir);
    end
end

% 预先分配结果数组。这里不使用结构体数组，因此不会发生
% “在不同结构体之间进行下标赋值”的 MATLAB 字段匹配错误。
maxRecords = numel(scenarioNumbers) * numel(algorithmNames) * numRuns;
compactRuns = cell(maxRecords,1);

recScenario = nan(maxRecords,1);
recCandidate = strings(maxRecords,1);
recAlgorithm = strings(maxRecords,1);
recRun = nan(maxRecords,1);
recSeed = nan(maxRecords,1);
recFeasible = false(maxRecords,1);
recF = nan(maxRecords,1);
recCV = nan(maxRecords,1);
recRuntime = nan(maxRecords,1);
recFEs = nan(maxRecords,1);
recPathLength = nan(maxRecords,1);
recEnergy = nan(maxRecords,1);
recRisk = nan(maxRecords,1);
recFlightTime = nan(maxRecords,1);
recMinClearance = nan(maxRecords,1);

recordCount = 0;
compactCount = 0;

%% 5. 逐场景、逐算法运行
for scenarioIndex = 1:numel(scenarioNumbers)
    scenarioNumber = scenarioNumbers(scenarioIndex);
    candidateId = candidateIds{scenarioNumber};

    fprintf('\n------------------------------------------------------------\n');
    fprintf('Building selected S%d environment: %s\n', ...
        scenarioNumber,candidateId);

    % 同一场景只构建一次环境和问题，避免重复读取 DEM 与建立缓存。
    [problem,env,cfgScene] = make_problem_from_candidate(candidateId,cfg);

    scenarioRuns = cell(numel(algorithmNames),numRuns);

    for algorithmIndex = 1:numel(algorithmNames)
        algorithmName = algorithmNames{algorithmIndex};
        fprintf('\n[%s | %s]\n',candidateId,algorithmName);

        for runIndex = 1:numRuns
            % 同一场景、同一 run 下，各算法使用相同随机种子。
            runSeed = baseSeed + 1000*scenarioNumber + runIndex;
            cfgRun = cfgScene;
            cfgRun.algorithm.seed = runSeed;

            startClock = tic;
            [bestCost,bestZ,convergence,output] = ...
                run_algorithm_by_name(algorithmName,problem,cfgRun); %#ok<ASGLU>
            elapsed = toc(startClock);

            bestResult = output.bestResult;
            actualFEs = read_field(output,'actualFEs',cfgRun.algorithm.MaxFEs);
            reportedRuntime = read_field(output,'runtime',elapsed);

            runData = struct();
            runData.scenarioNumber = scenarioNumber;
            runData.candidateId = candidateId;
            runData.algorithm = algorithmName;
            runData.run = runIndex;
            runData.seed = runSeed;
            runData.bestResult = bestResult;
            runData.convergence = convergence;
            runData.runtime = reportedRuntime;
            runData.actualFEs = actualFEs;
            scenarioRuns{algorithmIndex,runIndex} = runData;

            compactCount = compactCount + 1;
            compactRuns{compactCount} = runData;

            % 将本次运行直接写入预分配数组，不经过结构体数组赋值。
            recordCount = recordCount + 1;
            recScenario(recordCount) = scenarioNumber;
            recCandidate(recordCount) = string(candidateId);
            recAlgorithm(recordCount) = string(algorithmName);
            recRun(recordCount) = runIndex;
            recSeed(recordCount) = runSeed;
            recFeasible(recordCount) = logical(bestResult.isFeasible);
            recF(recordCount) = bestResult.F;
            recCV(recordCount) = bestResult.CV;
            recRuntime(recordCount) = reportedRuntime;
            recFEs(recordCount) = actualFEs;
            recPathLength(recordCount) = read_nested(bestResult,{'cost','length'},NaN);
            recEnergy(recordCount) = read_nested(bestResult,{'cost','energy'},NaN);
            recRisk(recordCount) = read_nested(bestResult,{'cost','risk'},NaN);
            recFlightTime(recordCount) = read_nested(bestResult,{'cost','time'},NaN);
            recMinClearance(recordCount) = read_field(bestResult,'minClearance',NaN);

            fprintf(['  run=%d seed=%d feasible=%d F=%.6g CV=%.3g ' ...
                'time=%.2fs FEs=%d\n'],runIndex,runSeed, ...
                bestResult.isFeasible,bestResult.F,bestResult.CV, ...
                reportedRuntime,actualFEs);
        end
    end

    %% 6. 每个场景的路径叠加图
    if showPathFigures
        pathFig = figure('Color','w', ...
            'Name',sprintf('%s - quick path comparison',candidateId));
        pathAx = axes(pathFig);
        plot_environment_candidate(pathAx,env,cfgScene,'3d');
        hold(pathAx,'on');

        colors = lines(numel(algorithmNames));
        pathHandles = gobjects(0);
        pathLabels = cell(0);

        for algorithmIndex = 1:numel(algorithmNames)
            representativeIndex = select_deb_best_run( ...
                scenarioRuns(algorithmIndex,:), ...
                cfgScene.constraint.feasibilityTolerance);
            runData = scenarioRuns{algorithmIndex,representativeIndex};
            result = runData.bestResult;

            if isfield(result,'pathSamples') && ~isempty(result.pathSamples)
                P = result.pathSamples;
                pathHandles(end+1) = plot3(pathAx,P(:,1),P(:,2),P(:,3), ...
                    'LineWidth',2.1,'Color',colors(algorithmIndex,:)); %#ok<SAGROW>
                pathLabels{end+1} = sprintf( ...
                    '%s | feasible=%d | F=%.4g | CV=%.2g', ...
                    algorithmNames{algorithmIndex},result.isFeasible, ...
                    result.F,result.CV); %#ok<SAGROW>
            end
        end

        if ~isempty(pathHandles)
            legend(pathAx,pathHandles,pathLabels,'Location','best', ...
                'Interpreter','none');
        end
        title(pathAx,sprintf('%s: quick algorithm path comparison',candidateId), ...
            'Interpreter','none');

        if saveFigures
            save_figure_robust(pathFig, ...
                fullfile(resultDir,sprintf('%s_paths.png',candidateId)));
        end
    end

    %% 7. 每个场景的收敛曲线
    if showConvergenceFigures
        convFig = figure('Color','w', ...
            'Name',sprintf('%s - quick convergence',candidateId));
        tiledlayout(convFig,2,1,'TileSpacing','compact','Padding','compact');
        colors = lines(numel(algorithmNames));

        axF = nexttile;
        hold(axF,'on'); grid(axF,'on');
        fHandles = gobjects(0); fLabels = cell(0);

        axCV = nexttile;
        hold(axCV,'on'); grid(axCV,'on');

        for algorithmIndex = 1:numel(algorithmNames)
            representativeIndex = select_deb_best_run( ...
                scenarioRuns(algorithmIndex,:), ...
                cfgScene.constraint.feasibilityTolerance);
            runData = scenarioRuns{algorithmIndex,representativeIndex};
            c = runData.convergence;

            if isstruct(c) && isfield(c,'FE') && ~isempty(c.FE)
                h = plot(axF,c.FE,c.bestF,'LineWidth',1.8, ...
                    'Color',colors(algorithmIndex,:));
                fHandles(end+1) = h; %#ok<SAGROW>
                fLabels{end+1} = algorithmNames{algorithmIndex}; %#ok<SAGROW>

                if isfield(c,'bestCV') && ~isempty(c.bestCV)
                    semilogy(axCV,c.FE,max(c.bestCV,eps),'LineWidth',1.8, ...
                        'Color',colors(algorithmIndex,:));
                end
            end
        end

        ylabel(axF,'Best objective F');
        title(axF,sprintf('%s: objective convergence',candidateId), ...
            'Interpreter','none');
        if ~isempty(fHandles)
            legend(axF,fHandles,fLabels,'Location','best','Interpreter','none');
        end

        xlabel(axCV,'Function evaluations');
        ylabel(axCV,'Best CV (log scale)');
        title(axCV,'Constraint-violation convergence');

        if saveFigures
            save_figure_robust(convFig, ...
                fullfile(resultDir,sprintf('%s_convergence.png',candidateId)));
        end
    end
end

%% 8. 输出并保存结果表
% 截取实际写入部分，并一次性构造 table。
idx = 1:recordCount;
compactRuns = compactRuns(1:compactCount);
resultTable = table( ...
    recScenario(idx),recCandidate(idx),recAlgorithm(idx),recRun(idx), ...
    recSeed(idx),recFeasible(idx),recF(idx),recCV(idx),recRuntime(idx), ...
    recFEs(idx),recPathLength(idx),recEnergy(idx),recRisk(idx), ...
    recFlightTime(idx),recMinClearance(idx), ...
    'VariableNames',{'Scenario','Candidate','Algorithm','Run','Seed', ...
    'Feasible','F','CV','Runtime_s','FEs','PathLength_m','Energy_J', ...
    'Risk','FlightTime_s','MinClearance_m'});
resultTable = sortrows(resultTable,{'Scenario','Algorithm','Run'});

fprintf('\n==================== Run-level results ====================\n');
disp(resultTable);

summaryTable = build_summary_table(resultTable);
fprintf('\n==================== Quick summary ========================\n');
disp(summaryTable);

runSettings = struct();
runSettings.scenarioNumbers = scenarioNumbers;
runSettings.candidateIds = candidateIds(scenarioNumbers);
runSettings.algorithmNames = algorithmNames;
runSettings.testProfile = testProfile;
runSettings.numRuns = numRuns;
runSettings.baseSeed = baseSeed;
runSettings.cfg = cfg;

if saveResults
    writetable(resultTable,fullfile(resultDir,'run_results.csv'));
    writetable(summaryTable,fullfile(resultDir,'summary.csv'));

    save(fullfile(resultDir,'quick_comparison_results.mat'), ...
        'compactRuns','resultTable','summaryTable','runSettings','-v7.3');

    fprintf('\nResults saved to:\n%s\n',resultDir);
end

fprintf(['\nThis is a low-budget preview. It verifies interfaces and visual trends; ' ...
    'do not use it as a formal paper comparison.\n']);

output = struct();
output.resultDir = resultDir;
output.resultTable = resultTable;
output.summaryTable = summaryTable;
output.compactRuns = compactRuns;
output.settings = runSettings;
end


%% ========================================================================
% Local helper functions
% ========================================================================
function cfg = apply_test_profile(cfg,profile)
%APPLY_TEST_PROFILE Set compact, deterministic test sizes.
profile = lower(strtrim(profile));

switch profile
    case 'smoke'
        cfg.path.K = 6;
        cfg.path.M = 50;
        cfg.path.enableAdaptiveSampling = false;
        cfg.path.maxAdaptivePoints = 50;
        cfg.path.maxRefineRounds = 0;
        cfg.algorithm.N = 6;
        cfg.algorithm.MaxFEs = 120;
        cfg.initialization.numSeedPaths = 1;
        cfg.initialization.gridSize = [18 18];
        cfg.initialization.maxAstarExpansions = 8e3;
        cfg.repair.maxRounds = 1;
        cfg.repair.maxInitRounds = 1;

    case 'quick'
        cfg.path.K = 8;
        cfg.path.M = 80;
        cfg.path.enableAdaptiveSampling = false;
        cfg.path.maxAdaptivePoints = 80;
        cfg.path.maxRefineRounds = 0;
        cfg.algorithm.N = 8;
        cfg.algorithm.MaxFEs = 240;
        cfg.initialization.numSeedPaths = 2;
        cfg.initialization.gridSize = [25 25];
        cfg.initialization.maxAstarExpansions = 2e4;
        cfg.repair.maxRounds = 1;
        cfg.repair.maxInitRounds = 1;

    case 'balanced'
        cfg.path.K = 10;
        cfg.path.M = 140;
        cfg.path.enableAdaptiveSampling = false;
        cfg.path.maxAdaptivePoints = 140;
        cfg.path.maxRefineRounds = 0;
        cfg.algorithm.N = 15;
        cfg.algorithm.MaxFEs = 1500;
        cfg.initialization.numSeedPaths = 3;
        cfg.initialization.gridSize = [35 35];
        cfg.initialization.maxAstarExpansions = 6e4;
        cfg.repair.maxRounds = 2;
        cfg.repair.maxInitRounds = 1;

    otherwise
        error('未知 testProfile：%s。可选 smoke、quick、balanced。',profile);
end
end

function [bestCost,bestZ,convergence,output] = ...
        run_algorithm_by_name(name,problem,cfg)
%RUN_ALGORITHM_BY_NAME Dispatch supported algorithms through one interface.
key = upper(regexprep(name,'[^A-Z0-9]',''));

switch key
    case {'TAASFPO'}
        [bestCost,bestZ,convergence,output] = TAAS_FPO(problem,cfg);
    case {'NFPO','FPON'}
        [bestCost,bestZ,convergence,output] = N_FPO(problem,cfg);
    case {'ASAFPO'}
        [bestCost,bestZ,convergence,output] = ASA_FPO(problem,cfg);
    case {'PSO'}
        [bestCost,bestZ,convergence,output] = PSO_constrained(problem,cfg);
    case {'DE'}
        [bestCost,bestZ,convergence,output] = DE_constrained(problem,cfg);
    case {'GWO'}
        [bestCost,bestZ,convergence,output] = GWO_constrained(problem,cfg);
    otherwise
        error('不支持的算法名称：%s',name);
end
end

function summary = build_summary_table(T)
%BUILD_SUMMARY_TABLE Summarize runs without structure-array assignment.
keys = unique(T(:,{'Scenario','Candidate','Algorithm'}),'rows','stable');
n = height(keys);

Runs = zeros(n,1);
FeasibleRate = nan(n,1);
MedianFeasibleF = nan(n,1);
BestFeasibleF = nan(n,1);
MedianCV = nan(n,1);
MeanRuntime_s = nan(n,1);
MedianPathLength_m = nan(n,1);
MedianEnergy_J = nan(n,1);

for i = 1:n
    mask = T.Scenario == keys.Scenario(i) & ...
        T.Candidate == keys.Candidate(i) & ...
        T.Algorithm == keys.Algorithm(i);
    G = T(mask,:);
    feasibleF = G.F(G.Feasible);

    Runs(i) = height(G);
    FeasibleRate(i) = mean(double(G.Feasible));
    if ~isempty(feasibleF)
        MedianFeasibleF(i) = median(feasibleF);
        BestFeasibleF(i) = min(feasibleF);
    end
    MedianCV(i) = median(G.CV);
    MeanRuntime_s(i) = mean(G.Runtime_s);
    MedianPathLength_m(i) = median_omitnan_local(G.PathLength_m);
    MedianEnergy_J(i) = median_omitnan_local(G.Energy_J);
end

summary = table(keys.Scenario,keys.Candidate,keys.Algorithm,Runs, ...
    FeasibleRate,MedianFeasibleF,BestFeasibleF,MedianCV,MeanRuntime_s, ...
    MedianPathLength_m,MedianEnergy_J, ...
    'VariableNames',{'Scenario','Candidate','Algorithm','Runs', ...
    'FeasibleRate','MedianFeasibleF','BestFeasibleF','MedianCV', ...
    'MeanRuntime_s','MedianPathLength_m','MedianEnergy_J'});
end

function value = median_omitnan_local(x)
%MEDIAN_OMITNAN_LOCAL Compatibility helper independent of toolboxes/version syntax.
x = x(~isnan(x));
if isempty(x)
    value = NaN;
else
    value = median(x);
end
end

function index = select_deb_best_run(runCells,tolerance)
%SELECT_DEB_BEST_RUN Select one visualization run by Deb feasibility rule.
index = 1;
for i = 2:numel(runCells)
    if deb_better_quick(runCells{i}.bestResult, ...
            runCells{index}.bestResult,tolerance)
        index = i;
    end
end
end

function tf = deb_better_quick(a,b,tolerance)
%DEB_BETTER_QUICK Minimal local Deb comparison for selecting saved runs.
aFeasible = a.CV <= tolerance;
bFeasible = b.CV <= tolerance;

if aFeasible && ~bFeasible
    tf = true;
elseif ~aFeasible && bFeasible
    tf = false;
elseif aFeasible && bFeasible
    tf = a.F < b.F;
else
    if abs(a.CV-b.CV) > tolerance
        tf = a.CV < b.CV;
    else
        tf = a.F < b.F;
    end
end
end

function value = read_field(s,name,defaultValue)
%READ_FIELD Read a structure field with a safe default.
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    value = s.(name);
else
    value = defaultValue;
end
end

function value = read_nested(s,path,defaultValue)
%READ_NESTED Read nested structure fields without throwing an error.
value = s;
for i = 1:numel(path)
    if ~isstruct(value) || ~isfield(value,path{i})
        value = defaultValue;
        return;
    end
    value = value.(path{i});
end
if isempty(value)
    value = defaultValue;
end
end

function save_figure_robust(fig,fileName)
%SAVE_FIGURE_ROBUST Prefer exportgraphics and fall back to saveas.
try
    exportgraphics(fig,fileName,'Resolution',180);
catch
    saveas(fig,fileName);
end
end


function value = read_option(options,name,defaultValue)
%READ_OPTION 读取可选配置字段，字段不存在或为空时使用默认值。
if isstruct(options) && isfield(options,name) && ~isempty(options.(name))
    value = options.(name);
else
    value = defaultValue;
end
end
