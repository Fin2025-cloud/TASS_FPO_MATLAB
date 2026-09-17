function report = visualize_formal_results(resultDir, userOptions)
%VISUALIZE_FORMAL_RESULTS 对 旧版主入口 选项 3 的已保存结果进行可视化。
%
% 适用工程
% -------------------------------------------------------------------------
% 本函数针对 TAAS_FPO_MATLAB v1.0.3 的实际结果结构编写。
%
% FPO_LAB 正式实验菜单 后，结果默认保存在：
%   <项目根目录>/results/formal_equal_FE/
%
% 每次运行保存为：
%   scenario_S1/TAAS-FPO/TAAS-FPO_S1_run001_seed201001.mat
%
% MAT 文件中包含：
%   record              单次运行的标量摘要；
%   fullData.cfg        本次运行配置；
%   fullData.env        本次运行环境；
%   fullData.bestZ      最优决策向量；
%   fullData.curve      以真实函数评价次数 FE 记录的收敛曲线；
%   fullData.output     算法完整输出。
%
% 本函数只读取已保存文件，不重新运行算法，也不重新评价候选路径，因此不会
% 改变实验数据、随机数或函数评价次数。
%
% 基本用法
% -------------------------------------------------------------------------
%   clear functions;
%   rehash;
%   startup;
%   report = visualize_formal_results;
%
% 指定结果目录：
%   resultDir = fullfile(pwd,'results','formal_equal_FE');
%   report = visualize_formal_results(resultDir);
%
% 生成每个算法的代表性单次详细图：
%   opts = struct('makePerAlgorithmDetails',true);
%   report = visualize_formal_results(resultDir,opts);
%
% 主要输出
% -------------------------------------------------------------------------
% 1. summary/
%    每个场景的可行率、可行目标值、首次可行 FE 和运行时间汇总图；
% 2. comparisons/
%    同一场景、同一 runID、同一环境种子下的多算法路径和收敛曲线；
% 3. representative_runs/
%    可选：各算法代表性运行的路径、收敛、策略概率和修复统计；
% 4. representative_runs.csv
%    每个场景用于多算法公平对比的代表 runID；
% 5. index.html
%    可在浏览器中集中查看全部 PNG 图。
%
% 真实性说明
% -------------------------------------------------------------------------
% - 汇总可行率的分母包括失败运行；
% - 目标值统计只使用 status="ok" 且 isFeasible=true 的运行；
% - 同场景多算法路径对比固定使用相同 runID 和 scenarioSeed；
% - 代表 runID 优先按 TAAS-FPO 的可行目标中位数选取；
% - 若 TAAS-FPO 在某场景无可行解，则按最小约束违反度选择 runID；
% - 不用“全局最好的一次运行”代替代表性结果。

%% 1. 初始化项目路径并解析输入
projectRoot = project_root();

% 当脚本放在项目根目录时，startup.m 与本文件位于同一级。
startupFile = fullfile(projectRoot,'startup.m');
if isfile(startupFile)
    % startup.m 在本工程中是函数文件，不能使用 run(startupFile) 当作脚本执行。
    % 先保证项目根目录在路径中，再正常调用 startup()。
    addpath(projectRoot);
    startup();
else
    % 若用户把本文件放到其他目录，则要求已手动执行 startup。
    warning('visualize_formal_results:StartupNotFound', ...
        ['未在本文件目录找到 startup.m。请确认已执行项目根目录中的 ', ...
         'startup.m，并确保 analysis 等目录已加入 MATLAB 路径。']);
end

if nargin < 1 || isempty(resultDir)
    resultDir = fullfile(projectRoot,'results','formal_equal_FE');
end

if nargin < 2 || isempty(userOptions)
    userOptions = struct();
end

opts = default_visualization_options();
opts = merge_options(opts,userOptions);

if ~isfolder(resultDir)
    error('visualize_formal_results:ResultDirNotFound', ...
        '结果目录不存在：%s',resultDir);
end

masterFile = fullfile(resultDir,'master_results.csv');
if ~isfile(masterFile)
    error('visualize_formal_results:MasterTableNotFound', ...
        ['未找到 master_results.csv：%s\n', ...
         '请确认 FPO_LAB 正式实验菜单 已运行完成。'],masterFile);
end

%% 2. 读取主结果表
T = readtable(masterFile);

requiredVariables = { ...
    'algorithm','scenario','runID','seed','scenarioSeed', ...
    'status','bestCost','isFeasible','bestCV','firstFeasibleFE','runtime'};

missingVariables = requiredVariables( ...
    ~ismember(requiredVariables,T.Properties.VariableNames));

if ~isempty(missingVariables)
    error('visualize_formal_results:MissingColumns', ...
        'master_results.csv 缺少字段：%s',strjoin(missingVariables,', '));
end

% 将文本字段统一为 string，减少 char、cellstr 和 categorical 差异。
T.algorithm = string(T.algorithm);
T.scenario = string(T.scenario);
T.status = string(T.status);

% isFeasible 在不同 MATLAB 版本中可能被读为 logical、double 或字符串。
T.isFeasible = to_logical_column(T.isFeasible);

%% 3. 确定算法和场景的显示顺序
preferredAlgorithms = [ ...
    "FPO-N","ASA-FPO","TAAS-FPO","PSO","DE","GWO"];

presentAlgorithms = unique(T.algorithm,'stable');
algorithmNames = preferredAlgorithms(ismember(preferredAlgorithms,presentAlgorithms));

extraAlgorithms = presentAlgorithms(~ismember(presentAlgorithms,algorithmNames));
algorithmNames = [algorithmNames, reshape(extraAlgorithms,1,[])];

scenarioNames = unique(T.scenario,'stable');
scenarioNumbers = arrayfun(@scenario_number,scenarioNames);
[~,scenarioOrder] = sort(scenarioNumbers);
scenarioNames = scenarioNames(scenarioOrder);

if isempty(algorithmNames) || isempty(scenarioNames)
    error('visualize_formal_results:EmptyTable', ...
        '主结果表中没有可视化所需的算法或场景记录。');
end

%% 4. 创建独立输出目录
if strlength(string(opts.outputDir)) == 0
    timeTag = datestr(now,'yyyymmdd_HHMMSS');
    outputDir = fullfile(resultDir,['figures_' timeTag]);
else
    outputDir = char(opts.outputDir);
end

summaryDir = fullfile(outputDir,'summary');
comparisonDir = fullfile(outputDir,'comparisons');
detailDir = fullfile(outputDir,'representative_runs');

ensure_folder(outputDir);
ensure_folder(summaryDir);
ensure_folder(comparisonDir);
if opts.makePerAlgorithmDetails
    ensure_folder(detailDir);
end

generatedFiles = strings(0,1);
representativeRows = cell(0,5);

%% 5. 为每个场景生成汇总图和公平的代表性多算法对比
for scenarioIndex = 1:numel(scenarioNames)
    scenario = scenarioNames(scenarioIndex);
    scenarioTable = T(T.scenario == scenario,:);

    fprintf('\n[Visualization] Scenario %s\n',scenario);

    % 5.1 生成四项统计汇总图。
    summaryBase = fullfile(summaryDir, ...
        sprintf('summary_%s',sanitize_name(scenario)));

    figSummary = create_summary_figure( ...
        scenarioTable,scenario,algorithmNames,opts);

    files = export_figure(figSummary,summaryBase,opts);
    generatedFiles = [generatedFiles; string(files(:))]; %#ok<AGROW>
    close_if_required(figSummary,opts);

    % 5.2 选择一个代表 runID。所有算法均使用该 runID 对比，保证环境一致。
    [representativeRunID,selectionBasis] = ...
        select_representative_run(scenarioTable);

    % 该 runID 对应的 scenarioSeed 对所有算法应相同。
    runRows = scenarioTable(scenarioTable.runID == representativeRunID,:);
    if isempty(runRows)
        warning('visualize_formal_results:RepresentativeRunMissing', ...
            '场景 %s 未找到代表 runID=%d。',scenario,representativeRunID);
        continue;
    end

    scenarioSeed = runRows.scenarioSeed(1);

    representativeRows(end+1,:) = { ...
        char(scenario),representativeRunID,scenarioSeed, ...
        char(selectionBasis),height(runRows)}; %#ok<AGROW>

    % 5.3 加载同一 runID 下各算法的完整 MAT 文件。
    runData = struct('algorithm',{},'record',{},'fullData',{},'matFile',{});

    for algorithmIndex = 1:numel(algorithmNames)
        algorithm = algorithmNames(algorithmIndex);

        row = runRows(runRows.algorithm == algorithm,:);
        if isempty(row)
            warning('visualize_formal_results:AlgorithmRunMissing', ...
                '场景 %s、runID=%d 缺少算法 %s 的记录。', ...
                scenario,representativeRunID,algorithm);
            continue;
        end

        % 理论上每个算法、场景、runID 只有一行。若有重复，使用第一行并报警。
        if height(row) > 1
            warning('visualize_formal_results:DuplicateRecord', ...
                '场景 %s、runID=%d、算法 %s 存在重复记录，使用第一条。', ...
                scenario,representativeRunID,algorithm);
            row = row(1,:);
        end

        matFile = locate_run_mat_file(resultDir,row);

        if strlength(string(matFile)) == 0
            warning('visualize_formal_results:MatFileNotFound', ...
                '无法定位场景 %s、runID=%d、算法 %s 的 MAT 文件。', ...
                scenario,representativeRunID,algorithm);
            continue;
        end

        loaded = load(matFile,'record','fullData');

        if ~isfield(loaded,'fullData') || ...
                ~isfield(loaded.fullData,'output') || ...
                ~isfield(loaded.fullData.output,'bestResult')
            warning('visualize_formal_results:IncompleteMat', ...
                'MAT 文件缺少 fullData.output.bestResult：%s',matFile);
            continue;
        end

        item = struct();
        item.algorithm = algorithm;
        item.record = loaded.record;
        item.fullData = loaded.fullData;
        item.matFile = string(matFile);

        runData(end+1) = item; %#ok<AGROW>
    end

    if isempty(runData)
        warning('visualize_formal_results:NoRunData', ...
            '场景 %s 没有可用于详细绘图的完整 MAT 数据。',scenario);
        continue;
    end

    % 5.4 绘制同一场景、同一 runID 的多算法三维路径比较。
    pathBase = fullfile(comparisonDir, ...
        sprintf('path_comparison_%s_run%03d', ...
        sanitize_name(scenario),representativeRunID));

    figPath = create_path_comparison_figure( ...
        runData,scenario,representativeRunID);

    files = export_figure(figPath,pathBase,opts);
    generatedFiles = [generatedFiles; string(files(:))]; %#ok<AGROW>
    close_if_required(figPath,opts);

    % 5.5 绘制同一 FE 预算下的多算法收敛比较。
    convergenceBase = fullfile(comparisonDir, ...
        sprintf('convergence_comparison_%s_run%03d', ...
        sanitize_name(scenario),representativeRunID));

    figConvergence = create_convergence_comparison_figure( ...
        runData,scenario,representativeRunID);

    files = export_figure(figConvergence,convergenceBase,opts);
    generatedFiles = [generatedFiles; string(files(:))]; %#ok<AGROW>
    close_if_required(figConvergence,opts);

    % 5.6 可选：为各算法生成代表性单次详细图。
    if opts.makePerAlgorithmDetails
        for itemIndex = 1:numel(runData)
            item = runData(itemIndex);
            algSafe = sanitize_name(item.algorithm);
            basePrefix = fullfile(detailDir, ...
                sprintf('%s_%s_run%03d', ...
                sanitize_name(scenario),algSafe,representativeRunID));

            generatedFiles = [generatedFiles; ...
                make_single_run_figures(item,basePrefix,opts)]; %#ok<AGROW>
        end
    end
end

%% 6. 保存代表运行清单和可视化报告
representativeTable = cell2table(representativeRows, ...
    'VariableNames',{ ...
    'Scenario','RunID','ScenarioSeed','SelectionBasis','AvailableAlgorithms'});

representativeCsv = fullfile(outputDir,'representative_runs.csv');
writetable(representativeTable,representativeCsv);

% 生成简单 HTML 索引，集中查看 PNG 图。
htmlIndex = create_html_index(outputDir,generatedFiles);

report = struct();
report.inputResultDir = resultDir;
report.outputDir = outputDir;
report.masterResultsFile = masterFile;
report.representativeRunsFile = representativeCsv;
report.htmlIndex = htmlIndex;
report.generatedFiles = generatedFiles;
report.options = opts;
report.representativeRuns = representativeTable;

save(fullfile(outputDir,'visualization_report.mat'),'report','-v7.3');

fprintf('\n============================================================\n');
fprintf('正式实验结果可视化完成。\n');
fprintf('输入结果目录：%s\n',resultDir);
fprintf('图像输出目录：%s\n',outputDir);
fprintf('HTML 图集索引：%s\n',htmlIndex);
fprintf('============================================================\n');
end

function opts = default_visualization_options()
%DEFAULT_VISUALIZATION_OPTIONS 返回不会改变实验结果的绘图默认参数。

opts = struct();

% 'off' 适合批量导图；改为 'on' 可在 MATLAB 中逐幅显示。
opts.figureVisible = 'off';

% PNG 适合论文预览和 HTML 图集。
opts.exportPNG = true;

% FIG 可在 MATLAB 中继续编辑坐标轴、字体和图例。
opts.exportFIG = true;

% 正式论文常用 300 dpi。
opts.resolution = 300;

% 导出后关闭图窗，防止批量绘图占用过多内存。
opts.closeAfterExport = true;

% 默认只生成统计汇总和公平的多算法对比，避免一次生成上百幅图。
opts.makePerAlgorithmDetails = false;

% 留空时自动建立带时间戳的输出目录。
opts.outputDir = "";
end

function out = merge_options(base,override)
%MERGE_OPTIONS 用用户提供的字段覆盖默认值。

out = base;
if isempty(override)
    return;
end

names = fieldnames(override);
for index = 1:numel(names)
    out.(names{index}) = override.(names{index});
end
end

function logicalColumn = to_logical_column(value)
%TO_LOGICAL_COLUMN 将表格中的可行性字段稳定转换为 logical。

if islogical(value)
    logicalColumn = value;
elseif isnumeric(value)
    logicalColumn = value ~= 0;
else
    textValue = lower(strtrim(string(value)));
    logicalColumn = ismember(textValue,["true","1","yes"]);
end
end

function number = scenario_number(scenario)
%SCENARIO_NUMBER 提取 S1、S2 等场景编号，便于自然排序。

token = regexp(char(scenario),'\d+','match','once');
if isempty(token)
    number = inf;
else
    number = str2double(token);
end
end

function fig = create_summary_figure(T,scenario,algorithmNames,opts)
%CREATE_SUMMARY_FIGURE 创建单场景四指标汇总图。
%
% 目标值只对“正常结束且可行”的运行计算中位数，避免不可行路径因为目标值
% 较低而在图中被误判为优秀。

algorithmCount = numel(algorithmNames);

feasibleRate = nan(algorithmCount,1);
medianFeasibleCost = nan(algorithmCount,1);
medianFirstFeasibleFE = nan(algorithmCount,1);
medianRuntime = nan(algorithmCount,1);

for index = 1:algorithmCount
    algorithm = algorithmNames(index);
    rows = T(T.algorithm == algorithm,:);

    if isempty(rows)
        continue;
    end

    ok = strcmpi(rows.status,'ok');
    feasible = ok & rows.isFeasible;

    % 可行率分母保留所有运行；错误运行不会被删除。
    feasibleRate(index) = mean(double(feasible));

    feasibleCosts = rows.bestCost(feasible & isfinite(rows.bestCost));
    if ~isempty(feasibleCosts)
        medianFeasibleCost(index) = median(feasibleCosts,'omitnan');
    end

    firstFE = rows.firstFeasibleFE(feasible & isfinite(rows.firstFeasibleFE));
    if ~isempty(firstFE)
        medianFirstFeasibleFE(index) = median(firstFE,'omitnan');
    end

    runtimeValues = rows.runtime(ok & isfinite(rows.runtime));
    if ~isempty(runtimeValues)
        medianRuntime(index) = median(runtimeValues,'omitnan');
    end
end

fig = figure( ...
    'Name',sprintf('Summary %s',scenario), ...
    'Visible',opts.figureVisible, ...
    'Color','w', ...
    'Position',[100 100 1280 820]);

layout = tiledlayout(fig,2,2, ...
    'TileSpacing','compact','Padding','compact');

categoryLabels = categorical(cellstr(algorithmNames),cellstr(algorithmNames));

nexttile(layout);
bar(categoryLabels,feasibleRate);
ylim([0,1]);
ylabel('Feasible rate');
title('可行率（全部运行为分母）');
grid on;

nexttile(layout);
bar(categoryLabels,medianFeasibleCost);
ylabel('Median feasible objective F');
title('可行运行的综合目标中位数');
grid on;

nexttile(layout);
bar(categoryLabels,medianFirstFeasibleFE);
ylabel('Function evaluations');
title('首次找到可行解的 FE 中位数');
grid on;

nexttile(layout);
bar(categoryLabels,medianRuntime);
ylabel('Runtime / s');
title('运行时间中位数');
grid on;

title(layout,sprintf('Scenario %s: formal equal-FE experiment summary',scenario));
end

function [runID,basis] = select_representative_run(T)
%SELECT_REPRESENTATIVE_RUN 为同场景多算法比较选择公平的 runID。
%
% 优先从 TAAS-FPO 的可行运行中选择目标值最接近中位数的一次。
% 这样不会只展示最好结果，也不会让不同算法使用不同环境。
%
% 若 TAAS-FPO 没有可行运行，则选择其最小 CV 对应 runID；
% 若缺少 TAAS-FPO，则依次在当前场景所有算法中采用同样原则。

reference = T(T.algorithm == "TAAS-FPO",:);
if isempty(reference)
    reference = T;
end

ok = strcmpi(reference.status,'ok');
feasible = ok & reference.isFeasible & isfinite(reference.bestCost);

if any(feasible)
    candidates = reference(feasible,:);
    target = median(candidates.bestCost,'omitnan');
    [~,index] = min(abs(candidates.bestCost-target));
    runID = candidates.runID(index);
    basis = "TAAS-FPO feasible median-cost run";
    return;
end

validCV = ok & isfinite(reference.bestCV);
if any(validCV)
    candidates = reference(validCV,:);
    [~,index] = min(candidates.bestCV);
    runID = candidates.runID(index);
    basis = "minimum-CV run because no feasible TAAS-FPO run exists";
    return;
end

% 最后回退到最小 runID；同时明确记录选择依据。
runID = min(reference.runID);
basis = "minimum runID fallback";
end

function matFile = locate_run_mat_file(resultDir,row)
%LOCATE_RUN_MAT_FILE 根据主表记录定位单次完整 MAT 文件。

algorithm = string(row.algorithm(1));
scenario = string(row.scenario(1));
runID = row.runID(1);
seed = row.seed(1);

runFolder = fullfile( ...
    resultDir, ...
    ['scenario_' char(scenario)], ...
    sanitize_name(algorithm));

pattern = sprintf('*_run%03d_seed%d.mat',round(runID),round(seed));
files = dir(fullfile(runFolder,pattern));

if isempty(files)
    % 若目录结构曾被移动，使用递归搜索作为后备方案。
    files = dir(fullfile(resultDir,'**',pattern));
end

if isempty(files)
    matFile = "";
else
    matFile = fullfile(files(1).folder,files(1).name);
end
end

function fig = create_path_comparison_figure(runData,scenario,runID)
%CREATE_PATH_COMPARISON_FIGURE 绘制同一环境、同一 runID 的多算法三维路径。
%
% 绘图坐标范围只由环境边界决定，动态轨迹和路径不会把地形挤到画面一侧。
% 风场箭头不放入正式路径对比图，风场仍完整参与能耗和约束评价。

first = runData(1);
env = first.fullData.env;
fig = figure('Name',sprintf('Path comparison %s run %d',scenario,runID), ...
    'Visible','off','Color','w','Position',[100 100 1280 850]);
ax = axes(fig); hold(ax,'on');

% 仅为绘图降采样；保存环境和评价器仍使用完整地形矩阵。
Z=env.terrain.Z; x=env.terrain.x; y=env.terrain.y;
maxGrid=150;
step=max(1,ceil(max(size(Z))/maxGrid));
xs=x(1:step:end); ys=y(1:step:end); Zs=Z(1:step:end,1:step:end);
surf(ax,xs,ys,Zs,'EdgeColor','none','FaceAlpha',0.84,'HandleVisibility','off');
colormap(ax,parula);

if isfield(env,'staticObstacles')
    for obstacleIndex=1:numel(env.staticObstacles)
        obstacle=env.staticObstacles(obstacleIndex);
        if isfield(obstacle,'type')&&strcmpi(obstacle.type,'cylinder')
            [cx,cy,cz]=cylinder(obstacle.radius,28);
            cz=obstacle.zMin+(obstacle.zMax-obstacle.zMin).*cz;
            surf(ax,cx+obstacle.center(1),cy+obstacle.center(2),cz, ...
                'EdgeColor','none','FaceAlpha',0.26,'HandleVisibility','off');
        end
    end
end

maxArrivalTime=0;
for index=1:numel(runData)
    result=runData(index).fullData.output.bestResult;
    if isfield(result,'arrivalTime')&&~isempty(result.arrivalTime)
        maxArrivalTime=max(maxArrivalTime,result.arrivalTime(end));
    end
end
if isfield(env,'dynamicObstacles')&&maxArrivalTime>0
    for obstacleIndex=1:numel(env.dynamicObstacles)
        obstacle=env.dynamicObstacles(obstacleIndex);
        timeSamples=linspace(0,maxArrivalTime,80)';
        Pobs=obstacle.p0+timeSamples.*obstacle.velocity;
        inside=Pobs(:,1)>=env.xLim(1)&Pobs(:,1)<=env.xLim(2)& ...
            Pobs(:,2)>=env.yLim(1)&Pobs(:,2)<=env.yLim(2)& ...
            Pobs(:,3)>=env.zLim(1)&Pobs(:,3)<=env.zLim(2);
        Pobs=Pobs(inside,:);
        if size(Pobs,1)>=2
            plot3(ax,Pobs(:,1),Pobs(:,2),Pobs(:,3),'--','LineWidth',1.0, ...
                'HandleVisibility','off');
        end
    end
end

for index=1:numel(runData)
    result=runData(index).fullData.output.bestResult;
    if ~isfield(result,'pathSamples')||isempty(result.pathSamples),continue;end
    P=result.pathSamples;
    displayName=sprintf('%s | feasible=%d | F=%.4g | CV=%.3g', ...
        runData(index).algorithm,result.isFeasible,result.F,result.CV);
    plot3(ax,P(:,1),P(:,2),P(:,3),'LineWidth',2.0,'DisplayName',displayName);
end
plot3(ax,env.start(1),env.start(2),env.start(3),'o','MarkerSize',9, ...
    'MarkerFaceColor','g','DisplayName','Start');
plot3(ax,env.goal(1),env.goal(2),env.goal(3),'s','MarkerSize',9, ...
    'MarkerFaceColor','r','DisplayName','Goal');

xlabel(ax,'X / m');ylabel(ax,'Y / m');zlabel(ax,'Z / m');
title(ax,sprintf('Scenario %s, representative run %03d: path comparison',scenario,runID));
grid(ax,'on');box(ax,'on');
xPad=.025*diff(env.xLim);yPad=.025*diff(env.yLim);zPad=.035*max(diff(env.zLim),1);
xlim(ax,[env.xLim(1)-xPad env.xLim(2)+xPad]);
ylim(ax,[env.yLim(1)-yPad env.yLim(2)+yPad]);
zlim(ax,[env.zLim(1)-zPad env.zLim(2)+zPad]);
set(ax,'XLimMode','manual','YLimMode','manual','ZLimMode','manual');
view(ax,43,31);axis(ax,'vis3d');
camtarget(ax,[mean(env.xLim),mean(env.yLim),mean(env.zLim)]);
pbaspect(ax,[1.15 1.00 .72]);
legend(ax,'Location','eastoutside','Interpreter','none');
end

function fig = create_convergence_comparison_figure(runData,scenario,runID)
%CREATE_CONVERGENCE_COMPARISON_FIGURE 比较同一次运行的 F 和 CV 收敛过程。

fig = figure( ...
    'Name',sprintf('Convergence comparison %s run %d',scenario,runID), ...
    'Visible','off', ...
    'Color','w', ...
    'Position',[100 100 1200 820]);

layout = tiledlayout(fig,2,1, ...
    'TileSpacing','compact','Padding','compact');

nexttile(layout);
hold on;
for index = 1:numel(runData)
    curve = runData(index).fullData.curve;
    if ~isfield(curve,'FE') || isempty(curve.FE)
        continue;
    end

    plot(curve.FE,curve.bestF, ...
        'LineWidth',1.5, ...
        'DisplayName',char(runData(index).algorithm));
end
xlabel('Function evaluations (FEs)');
ylabel('Best objective F');
title('Objective convergence');
grid on;
legend('Location','eastoutside','Interpreter','none');

nexttile(layout);
hold on;
for index = 1:numel(runData)
    curve = runData(index).fullData.curve;
    if ~isfield(curve,'FE') || isempty(curve.FE)
        continue;
    end

    semilogy(curve.FE,max(curve.bestCV,eps), ...
        'LineWidth',1.5, ...
        'DisplayName',char(runData(index).algorithm));
end
xlabel('Function evaluations (FEs)');
ylabel('Best constraint violation CV');
title('Constraint-violation convergence');
grid on;
legend('Location','eastoutside','Interpreter','none');

title(layout,sprintf( ...
    'Scenario %s, representative run %03d: equal-FE convergence', ...
    scenario,runID));
end

function files = make_single_run_figures(item,basePrefix,opts)
%MAKE_SINGLE_RUN_FIGURES 调用工程已有绘图函数生成代表性详细图。

files = strings(0,1);
cfg = item.fullData.cfg;
env = item.fullData.env;
curve = item.fullData.curve;
output = item.fullData.output;
result = output.bestResult;

% 1. 三维地形与最优路径。
fig = figure( ...
    'Name',[char(item.algorithm) ' 3-D path'], ...
    'Visible',opts.figureVisible, ...
    'Color','w', ...
    'Position',[100 100 1200 820]);
plot_path_3d(env,result,cfg);
newFiles = export_figure(fig,[basePrefix '_path3d'],opts);
files = [files; string(newFiles(:))]; %#ok<AGROW>
close_if_required(fig,opts);

% 2. FE 收敛曲线。
fig = figure( ...
    'Name',[char(item.algorithm) ' convergence'], ...
    'Visible',opts.figureVisible, ...
    'Color','w', ...
    'Position',[100 100 1000 700]);
plot_convergence_fe(curve);
newFiles = export_figure(fig,[basePrefix '_convergence'],opts);
files = [files; string(newFiles(:))]; %#ok<AGROW>
close_if_required(fig,opts);

% 3. 七策略概率。基线算法通常没有该字段，自动跳过。
if isfield(output,'log') && ...
        isfield(output.log,'FE') && ...
        ~isempty(output.log.FE) && ...
        isfield(output.log,'strategyProb') && ...
        ~isempty(output.log.strategyProb)

    fig = figure( ...
        'Name',[char(item.algorithm) ' strategy probabilities'], ...
        'Visible',opts.figureVisible, ...
        'Color','w', ...
        'Position',[100 100 1100 720]);
    plot_strategy_prob(output.log);
    newFiles = export_figure(fig,[basePrefix '_strategy_prob'],opts);
    files = [files; string(newFiles(:))]; %#ok<AGROW>
    close_if_required(fig,opts);
end

% 4. 修复动作统计。只有使用 CDR 的算法才会产生实际统计。
if isfield(output,'repairStats') && ...
        isstruct(output.repairStats) && ...
        isfield(output.repairStats,'byType') && ...
        ~isempty(fieldnames(output.repairStats.byType))

    fig = figure( ...
        'Name',[char(item.algorithm) ' repair statistics'], ...
        'Visible',opts.figureVisible, ...
        'Color','w', ...
        'Position',[100 100 900 650]);
    plot_repair_stats(output.repairStats);
    newFiles = export_figure(fig,[basePrefix '_repair_stats'],opts);
    files = [files; string(newFiles(:))]; %#ok<AGROW>
    close_if_required(fig,opts);
end
end

function files = export_figure(fig,baseFile,opts)
%EXPORT_FIGURE 按选项导出 PNG 和 FIG。

files = strings(0,1);

if opts.exportPNG
    pngFile = [baseFile '.png'];

    if exist('exportgraphics','file') == 2
        exportgraphics(fig,pngFile,'Resolution',opts.resolution);
    else
        print(fig,pngFile,'-dpng',sprintf('-r%d',opts.resolution));
    end

    files(end+1,1) = string(pngFile); %#ok<AGROW>
end

if opts.exportFIG
    figFile = [baseFile '.fig'];
    savefig(fig,figFile);
    files(end+1,1) = string(figFile); %#ok<AGROW>
end
end

function close_if_required(fig,opts)
%CLOSE_IF_REQUIRED 导出后按选项关闭图窗。

if opts.closeAfterExport && isgraphics(fig)
    close(fig);
end
end

function ensure_folder(folder)
%ENSURE_FOLDER 创建不存在的目录。

if ~isfolder(folder)
    mkdir(folder);
end
end

function safeName = sanitize_name(value)
%SANITIZE_NAME 与实验保存函数采用相同的文件名清洗规则。

safeName = regexprep(char(string(value)),'[^a-zA-Z0-9_-]','_');
end

function htmlFile = create_html_index(outputDir,generatedFiles)
%CREATE_HTML_INDEX 为已导出的 PNG 生成简单本地图集。
%
% HTML 只链接 PNG，不复制、不修改原始实验文件。

pngFiles = generatedFiles(endsWith(lower(generatedFiles),'.png'));

htmlFile = fullfile(outputDir,'index.html');
fileID = fopen(htmlFile,'w','n','UTF-8');

if fileID < 0
    warning('visualize_formal_results:HtmlCreateFailed', ...
        '无法创建 HTML 索引：%s',htmlFile);
    htmlFile = "";
    return;
end

cleanupObject = onCleanup(@() fclose(fileID)); %#ok<NASGU>

fprintf(fileID,'<!doctype html>\n');
fprintf(fileID,'<html lang="zh-CN"><head><meta charset="utf-8">\n');
fprintf(fileID,'<title>TAAS-FPO Formal Experiment Visualization</title>\n');
fprintf(fileID,['<style>', ...
    'body{font-family:Arial,\"Microsoft YaHei\",sans-serif;', ...
    'max-width:1400px;margin:24px auto;padding:0 18px;background:#f5f6f8;}', ...
    'h1{font-size:24px;}h2{font-size:18px;margin-top:30px;}', ...
    '.item{background:white;border:1px solid #ddd;border-radius:8px;', ...
    'padding:12px;margin:14px 0;}', ...
    'img{max-width:100%;height:auto;display:block;margin:auto;}', ...
    '.path{font-size:12px;color:#555;word-break:break-all;margin-top:8px;}', ...
    '</style></head><body>\n']);

fprintf(fileID,'<h1>TAAS-FPO 正式等 FE 实验可视化</h1>\n');
fprintf(fileID,['<p>本页面仅展示已保存结果生成的图像；', ...
    '可视化过程未重新运行算法或修改实验数据。</p>\n']);

for index = 1:numel(pngFiles)
    absoluteFile = char(pngFiles(index));
    relativeFile = strrep(absoluteFile,[outputDir filesep],'');
    relativeWebPath = strrep(relativeFile,filesep,'/');

    fprintf(fileID,'<div class="item">\n');
    fprintf(fileID,'<img src="%s" alt="%s">\n', ...
        html_escape(relativeWebPath),html_escape(relativeFile));
    fprintf(fileID,'<div class="path">%s</div>\n',html_escape(relativeFile));
    fprintf(fileID,'</div>\n');
end

fprintf(fileID,'</body></html>\n');
end

function output = html_escape(input)
%HTML_ESCAPE 转义 HTML 特殊字符。

output = strrep(input,'&','&amp;');
output = strrep(output,'<','&lt;');
output = strrep(output,'>','&gt;');
output = strrep(output,'"','&quot;');
end
