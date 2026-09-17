function [ids,selection,selectionFile] = load_environment_selection(cfg)
%LOAD_ENVIRONMENT_SELECTION 读取并验证环境工作室保存的 S1-S6 候选组合。
%
% 输出 ids 为 1×6 cell，每个位置严格对应 S1 至 S6。本函数只读取和验证
% 编号，不构建地形、不运行算法。

if nargin < 1 || isempty(cfg)
    cfg = environment_config();
end
projectRoot = fileparts(fileparts(mfilename('fullpath')));
selectionFile = resolve_project_path(projectRoot,cfg.environment.selectionFile);

if ~isfile(selectionFile)
    error('load_environment_selection:MissingFile', ...
        ['未找到环境选择文件：%s\n请先运行 FPO_LAB，', ...
         '使用选项5保存每个 S1-S6 的候选环境。'],selectionFile);
end

data = load(selectionFile,'selection');
if ~isfield(data,'selection') || ~isstruct(data.selection)
    error('load_environment_selection:InvalidFile', ...
        '选择文件中缺少结构体变量 selection：%s',selectionFile);
end
selection = data.selection;
if ~isfield(selection,'candidateIds') || numel(selection.candidateIds) ~= 6
    error('load_environment_selection:CandidateIds', ...
        'selection.candidateIds 必须包含六个环境编号。');
end

ids = cellstr(string(selection.candidateIds(:)'));
for scenarioId = 1:6
    item = get_environment_candidate(ids{scenarioId});
    if item.scenarioId ~= scenarioId
        error('load_environment_selection:ScenarioMismatch', ...
            '%s 属于 S%d，不能放在 S%d 位置。', ...
            ids{scenarioId},item.scenarioId,scenarioId);
    end
end
end

function pathValue = resolve_project_path(projectRoot,pathValue)
pathValue = char(string(pathValue));
if isempty(pathValue), return; end
if ~is_absolute_path(pathValue)
    pathValue = fullfile(projectRoot,pathValue);
end
end
function tf = is_absolute_path(p)
tf = startsWith(p,filesep) || ~isempty(regexp(p,'^[A-Za-z]:[\\/]','once'));
end
