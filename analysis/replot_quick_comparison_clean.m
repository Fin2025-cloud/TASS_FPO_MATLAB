function replot_quick_comparison_clean(resultMatFile)
%REPLOT_QUICK_COMPARISON_CLEAN 根据已保存结果重新绘图，不重新运行算法。
%
% 用法1：
%   replot_quick_comparison_clean
%   然后在文件选择框中选择 quick_comparison_results.mat。
%
% 用法2：
%   replot_quick_comparison_clean('完整路径/quick_comparison_results.mat')
%
% 需要先用本补丁中的 plot_environment_candidate.m 覆盖原绘图函数。

if nargin < 1 || isempty(resultMatFile)
    [fileName,filePath] = uigetfile('quick_comparison_results.mat', ...
        '选择快速算法对比结果');
    if isequal(fileName,0)
        fprintf('已取消重新绘图。\n');
        return;
    end
    resultMatFile = fullfile(filePath,fileName);
end

if ~isfile(resultMatFile)
    error('找不到结果文件：%s',resultMatFile);
end

startup;
S = load(resultMatFile,'compactRuns','runSettings');
if ~isfield(S,'compactRuns') || ~isfield(S,'runSettings')
    error('结果 MAT 中缺少 compactRuns 或 runSettings。');
end

compactRuns = S.compactRuns;
runSettings = S.runSettings;
resultDir = fileparts(resultMatFile);

scenarioNumbers = runSettings.scenarioNumbers;
algorithmNames = runSettings.algorithmNames;
candidateIds = runSettings.candidateIds;
cfg = runSettings.cfg;

if isstring(algorithmNames), algorithmNames = cellstr(algorithmNames); end
if isstring(candidateIds), candidateIds = cellstr(candidateIds); end

for sIndex = 1:numel(scenarioNumbers)
    scenarioNumber = scenarioNumbers(sIndex);
    candidateId = candidateIds{sIndex};

    % 只重建环境，不运行优化算法。
    env = build_environment_candidate(candidateId,cfg);

    fig = figure('Color','w', ...
        'Name',sprintf('%s - cleaned path comparison',candidateId));
    ax = axes(fig);
    plot_environment_candidate(ax,env,cfg,'3d');
    hold(ax,'on');

    colors = lines(numel(algorithmNames));
    pathHandles = gobjects(0);
    pathLabels = cell(0);

    for aIndex = 1:numel(algorithmNames)
        name = algorithmNames{aIndex};
        runs = matching_runs(compactRuns,scenarioNumber,name);
        if isempty(runs)
            continue;
        end

        runData = choose_deb_best(runs);
        result = runData.bestResult;

        if isfield(result,'pathSamples') && ~isempty(result.pathSamples)
            P = result.pathSamples;
            pathHandles(end+1) = plot3(ax,P(:,1),P(:,2),P(:,3), ...
                'LineWidth',2.1,'Color',colors(aIndex,:)); %#ok<AGROW>
            pathLabels{end+1} = sprintf( ...
                '%s | feasible=%d | F=%.4g | CV=%.2g', ...
                name,result.isFeasible,result.F,result.CV); %#ok<AGROW>
        end
    end

    if ~isempty(pathHandles)
        legend(ax,pathHandles,pathLabels, ...
            'Location','best','Interpreter','none');
    end

    title(ax,sprintf('%s: quick algorithm path comparison',candidateId), ...
        'Interpreter','none');

    outFile = fullfile(resultDir,sprintf('%s_paths_clean.png',candidateId));
    try
        exportgraphics(fig,outFile,'Resolution',220);
    catch
        saveas(fig,outFile);
    end
    fprintf('已生成：%s\n',outFile);
end
end

function runs = matching_runs(compactRuns,scenarioNumber,algorithmName)
runs = {};
for i = 1:numel(compactRuns)
    r = compactRuns{i};
    if isempty(r), continue; end
    if r.scenarioNumber == scenarioNumber && strcmpi(r.algorithm,algorithmName)
        runs{end+1} = r; %#ok<AGROW>
    end
end
end

function best = choose_deb_best(runs)
best = runs{1};
for i = 2:numel(runs)
    a = runs{i}.bestResult;
    b = best.bestResult;
    if deb_result_better(a,b)
        best = runs{i};
    end
end
end

function tf = deb_result_better(a,b)
if logical(a.isFeasible) && ~logical(b.isFeasible)
    tf = true;
elseif ~logical(a.isFeasible) && logical(b.isFeasible)
    tf = false;
elseif logical(a.isFeasible) && logical(b.isFeasible)
    tf = a.F < b.F;
else
    if a.CV < b.CV
        tf = true;
    elseif a.CV > b.CV
        tf = false;
    else
        tf = a.F < b.F;
    end
end
end
