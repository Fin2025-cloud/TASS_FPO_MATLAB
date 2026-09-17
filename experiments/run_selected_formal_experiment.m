function masterTable = run_selected_formal_experiment(profile,userCfg,scenarioIds,algorithmNames)
%RUN_SELECTED_FORMAL_EXPERIMENT 运行环境工作室已选场景的统一比较实验。
%
% 示例：
%   cfg = formal_experiment_config('formal');
%   cfg.experiment.useParallel = true;
%   masterTable = run_selected_formal_experiment('formal',cfg,1:6, ...
%       {'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'});
%
% 已完成的运行会在 resume=true 时自动跳过；环境、算法、预算或选择发生变化
% 时，实验签名检查会阻止结果混写。

if nargin < 1 || isempty(profile), profile = 'formal'; end
cfg = formal_experiment_config(profile);
if nargin >= 2 && ~isempty(userCfg), cfg = merge_structs(cfg,userCfg); end
if nargin < 3 || isempty(scenarioIds), scenarioIds = 1:6; end
if nargin < 4 || isempty(algorithmNames)
    algorithmNames = {'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'};
end
cfg.environment.mode = 'selected_library';
cfg.experiment.environmentMode = cfg.environment.mode;

% 在任何预检或场景构建之前只读取一次选择文件。由此得到的六个编号随后写入
% cfg，确保长实验期间即使选择文件被修改，当前实验的问题实例也不会改变。
[cfg,~,~] = resolve_environment_selection(cfg);
validate_config(cfg);

preflight_formal_experiment(cfg,scenarioIds,algorithmNames);
masterTable = run_uav_experiments_selectable(cfg,scenarioIds,algorithmNames);
end
