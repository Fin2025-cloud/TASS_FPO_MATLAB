function report = diagnose_saved_altitude_clearance(resultDir,scenarioIds)
%DIAGNOSE_SAVED_ALTITUDE_CLEARANCE 用已保存结果诊断航迹是否真正利用地形。
%
% 本函数不会调用任何优化算法，也不会改变 master_results.csv。它直接读取
% 选项 3 已保存的 MAT 文件，并计算每条代表性航迹的：
%   * 最小、平均和最大离地高度 AGL；
%   * 航迹高度范围；
%   * 地形高程范围；
%   * 最大 AGL 与场景地形起伏之比。
%
% 每个场景使用 TAAS-FPO 可行结果中最接近中位目标值的 runID，并在同一
% runID 下加载所有算法，从而与 visualize_formal_results 的公平比较原则一致。
%
% 示例：
%   diagnose_saved_altitude_clearance( ...
%       fullfile(pwd,'results','formal_equal_FE'),[2 3]);

startup();
projectRoot = project_root();
if nargin < 1 || isempty(resultDir)
    resultDir = fullfile(projectRoot,'results','formal_equal_FE');
end
if nargin < 2 || isempty(scenarioIds)
    scenarioIds = 1:6;
end
masterFile = fullfile(resultDir,'master_results.csv');
if ~isfile(masterFile)
    error('diagnose_saved_altitude_clearance:MissingMaster', ...
        '未找到 master_results.csv：%s',masterFile);
end
T = readtable(masterFile);
T.algorithm = string(T.algorithm);
T.scenario = string(T.scenario);

outputDir = fullfile(resultDir,['altitude_diagnostics_' datestr(now,'yyyymmdd_HHMMSS')]);
mkdir(outputDir);
rows = cell(0,14);

for sid = scenarioIds(:)'
    scenario = "S"+string(sid);
    Ts = T(T.scenario==scenario,:);
    if isempty(Ts)
        warning('diagnose_saved_altitude_clearance:ScenarioMissing', ...
            '主表中没有 %s。',scenario);
        continue;
    end
    runID = select_representative_run(Ts);
    runRows = Ts(Ts.runID==runID,:);

    fig = figure('Color','w','Name',char(scenario+" altitude and AGL"));
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
    ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
    ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
    terrainDrawn = false;

    for k = 1:height(runRows)
        row = runRows(k,:);
        matFile = locate_mat_file(resultDir,row);
        if strlength(matFile)==0
            warning('diagnose_saved_altitude_clearance:MatMissing', ...
                '缺少 %s %s run %d 的 MAT 文件。', ...
                row.algorithm,row.scenario,row.runID);
            continue;
        end
        loaded = load(matFile,'fullData');
        if ~isfield(loaded,'fullData') || ~isfield(loaded.fullData,'output') || ...
                ~isfield(loaded.fullData.output,'bestResult')
            continue;
        end
        result = loaded.fullData.output.bestResult;
        if ~isfield(result,'pathSamples') || isempty(result.pathSamples)
            continue;
        end
        P = result.pathSamples;
        env = loaded.fullData.env;
        terrainZ = terrain_height(env,P(:,1),P(:,2));
        agl = P(:,3)-terrainZ;
        horizontalDistance = [0;cumsum(hypot(diff(P(:,1)),diff(P(:,2))))];

        if ~terrainDrawn
            plot(ax1,horizontalDistance,terrainZ,'k--','LineWidth',1.2, ...
                'DisplayName','Terrain along first displayed path');
            terrainDrawn = true;
        end
        plot(ax1,horizontalDistance,P(:,3),'LineWidth',1.25, ...
            'DisplayName',char(row.algorithm));
        plot(ax2,horizontalDistance,agl,'LineWidth',1.25, ...
            'DisplayName',char(row.algorithm));

        fullTerrain = env.terrain.Z(isfinite(env.terrain.Z));
        relief = max(fullTerrain)-min(fullTerrain);
        rows(end+1,:) = { ... %#ok<AGROW>
            scenario,string(row.algorithm),runID,string(matFile), ...
            min(P(:,3)),mean(P(:,3)),max(P(:,3)), ...
            min(terrainZ),mean(terrainZ),max(terrainZ), ...
            min(agl),mean(agl),max(agl),max(agl)/max(relief,eps)};
    end

    title(ax1,sprintf('%s representative run %03d: terrain and absolute altitude', ...
        scenario,runID),'Interpreter','none');
    xlabel(ax1,'Horizontal cumulative distance / m');
    ylabel(ax1,'Elevation / m');
    legend(ax1,'Location','bestoutside','Interpreter','none');
    title(ax2,'Above-ground level (AGL)');
    xlabel(ax2,'Horizontal cumulative distance / m');
    ylabel(ax2,'AGL / m');
    yline(ax2,30,'k:','Minimum clearance 30 m','HandleVisibility','off');
    legend(ax2,'Location','bestoutside','Interpreter','none');
    exportgraphics(fig,fullfile(outputDir,sprintf('altitude_AGL_%s_run%03d.png', ...
        scenario,runID)),'Resolution',300);
    savefig(fig,fullfile(outputDir,sprintf('altitude_AGL_%s_run%03d.fig', ...
        scenario,runID)));
    close(fig);
end

report = cell2table(rows,'VariableNames',{ ...
    'Scenario','Algorithm','RunID','MATFile', ...
    'MinFlightZ_m','MeanFlightZ_m','MaxFlightZ_m', ...
    'MinTerrainZ_m','MeanTerrainZ_m','MaxTerrainZ_m', ...
    'MinAGL_m','MeanAGL_m','MaxAGL_m','MaxAGL_to_TerrainRelief'});
writetable(report,fullfile(outputDir,'altitude_clearance_diagnostics.csv'));
disp(report);
fprintf('诊断图和表已保存到：%s\n',outputDir);
end

function runID = select_representative_run(Ts)
% 优先使用 TAAS-FPO 可行结果的中位目标值代表运行。
Tref = Ts(Ts.algorithm=="TAAS-FPO",:);
if isempty(Tref), Tref = Ts; end
feasible = to_logical(Tref.isFeasible);
valid = Tref(feasible & isfinite(Tref.bestCost),:);
if ~isempty(valid)
    med = median(valid.bestCost);
    [~,idx] = min(abs(valid.bestCost-med));
    runID = valid.runID(idx);
    return;
end
if ismember('bestCV',Tref.Properties.VariableNames)
    [~,idx] = min(Tref.bestCV);
else
    idx = 1;
end
runID = Tref.runID(idx);
end

function value = to_logical(value)
if islogical(value)
    return;
elseif isnumeric(value)
    value = value~=0;
else
    value = ismember(lower(strtrim(string(value))),["true","1","yes"]);
end
end

function matFile = locate_mat_file(resultDir,row)
folder = fullfile(resultDir,"scenario_"+row.scenario, ...
    sanitize_name(row.algorithm));
pattern = sprintf('*_%s_run%03d_seed*.mat',char(row.scenario),row.runID);
files = dir(fullfile(folder,pattern));
if isempty(files)
    matFile = "";
else
    matFile = string(fullfile(files(1).folder,files(1).name));
end
end

function name = sanitize_name(value)
name = regexprep(char(string(value)),'[^a-zA-Z0-9_-]','_');
end
