function [env,candidateId] = build_experiment_environment(cfg,scenarioId,scenarioSeed)
%BUILD_EXPERIMENT_ENVIRONMENT 按配置构建 v1.1.1 冻结场景或已选候选场景。
%
% cfg.environment.mode:
%   'featured_v111'   - 使用 v1.1.1 的六个冻结环境；
%   'selected_library' - 使用环境工作室选项5保存的 S1-S6 候选。
%
% 本函数把候选环境的正式场景编号统一设为 S1...S6，并把原始候选编号保存
% 在 env.candidateId/env.meta.candidateId，避免结果目录和统计表因 “S3-A” 等
% 字符串而破坏旧分析脚本。

if nargin < 2 || isempty(scenarioId), scenarioId = 1; end
if nargin < 3 || isempty(scenarioSeed), scenarioSeed = 100000+1000*scenarioId; end
if ~ismember(scenarioId,1:6)
    error('build_experiment_environment:Scenario','scenarioId must be 1...6.');
end

mode = lower(char(safe_nested(cfg,{'environment','mode'},'featured_v111')));
switch mode
    case 'featured_v111'
        env = build_scenario_environment(cfg,scenarioId,scenarioSeed);
        candidateId = sprintf('V111-S%d',scenarioId);

    case 'selected_library'
        ids = safe_nested(cfg,{'environment','candidateIds'},{});
        if isempty(ids)
            ids = load_environment_selection(cfg);
        else
            ids = cellstr(string(ids(:)'));
        end
        candidateId = ids{scenarioId};
        item = get_environment_candidate(candidateId);
        if item.scenarioId ~= scenarioId
            error('build_experiment_environment:CandidateMismatch', ...
                '%s is not an S%d candidate.',candidateId,scenarioId);
        end
        env = build_environment_candidate(candidateId,cfg);
        scenarioSeed = item.seed;

    otherwise
        error('build_experiment_environment:Mode', ...
            'Unknown environment mode: %s',mode);
end

% 统一正式实验标识，同时保留候选编号和原始来源。
env.originalId = env.id;
env.id = sprintf('S%d',scenarioId);
env.scenarioId = scenarioId;
env.candidateId = candidateId;
env.seed = scenarioSeed;
if ~isfield(env,'meta') || ~isstruct(env.meta), env.meta = struct(); end
env.meta.candidateId = candidateId;
env.meta.environmentMode = mode;
env.meta.formalScenarioId = scenarioId;
env.meta.selectionStatus = 'frozen_for_current_experiment';

% 将真实地形目录信息映射到 v1.1.1 记录器使用的字段。
if isfield(env,'terrain') && isfield(env.terrain,'catalog')
    env.meta.catalog = env.terrain.catalog;
end
end

function value = safe_nested(s,path,defaultValue)
value = defaultValue;
for k = 1:numel(path)
    if ~isstruct(s) || ~isfield(s,path{k}), return; end
    s = s.(path{k});
end
value = s;
end
