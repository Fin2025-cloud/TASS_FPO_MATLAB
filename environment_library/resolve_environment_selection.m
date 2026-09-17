function [cfg,ids,selection] = resolve_environment_selection(cfg)
%RESOLVE_ENVIRONMENT_SELECTION 将已保存环境组合解析并冻结到配置副本。
%
% 本函数解决长时间实验中的一个关键一致性问题：正式实验启动后，即使用户
% 再次打开环境工作室并修改 selected_environments.mat，当前实验仍只使用启动
% 时读入 cfg.environment.candidateIds 的六个编号，不会在后续场景中悄然变化。
%
% 输入/输出：
%   cfg       - 输入配置；返回时 candidateIds 已固定为 1×6 cell。
%   ids       - 严格对应 S1...S6 的候选编号。
%   selection - 选择文件中的完整元数据；若调用者直接提供 candidateIds，则为
%               一个清晰的运行时快照结构体。
%
% 本函数不构建环境、不读取 DEM、不运行算法。

if nargin < 1 || isempty(cfg)
    cfg = formal_experiment_config('formal');
end
if ~isfield(cfg,'environment') || ~isstruct(cfg.environment)
    error('resolve_environment_selection:EnvironmentConfig', ...
        'cfg.environment is missing.');
end

mode = lower(char(string(safe_field(cfg.environment,'mode','featured_v111'))));
if ~strcmp(mode,'selected_library')
    ids = arrayfun(@(s)sprintf('V111-S%d',s),1:6,'UniformOutput',false);
    selection = struct('candidateIds',{ids},'status','featured_v111');
    return;
end

provided = safe_field(cfg.environment,'candidateIds',{});
if isempty(provided)
    [ids,selection] = load_environment_selection(cfg);
else
    ids = cellstr(string(provided(:)'));
    selection = struct('candidateIds',{ids}, ...
        'status','resolved_from_cfg_environment_candidateIds');
end

if numel(ids) ~= 6
    error('resolve_environment_selection:Count', ...
        'selected_library mode requires exactly six candidate IDs.');
end
for scenarioId = 1:6
    item = get_environment_candidate(ids{scenarioId});
    if item.scenarioId ~= scenarioId
        error('resolve_environment_selection:ScenarioMismatch', ...
            '%s belongs to S%d and cannot occupy S%d.', ...
            ids{scenarioId},item.scenarioId,scenarioId);
    end
end

% 写入当前配置副本；后续预检、清单冻结和正式运行均使用该固定数组。
cfg.environment.candidateIds = ids;
if ~isfield(cfg,'experiment') || ~isstruct(cfg.experiment)
    cfg.experiment = struct();
end
cfg.experiment.environmentMode = mode;
end

function value = safe_field(s,name,defaultValue)
if isstruct(s) && isfield(s,name)
    value = s.(name);
else
    value = defaultValue;
end
end
