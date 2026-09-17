function test_objective_normalization_resolution()
%TEST_OBJECTIVE_NORMALIZATION_RESOLUTION 验证目标归一化空参考值的确定性补齐。
%
% 测试背景
% -------------------------------------------------------------------------
% default_config 中 referenceLength 和 referenceTime 默认留空，因为这两个
% 参考值依赖当前任务的起点、终点和固定地速。make_problem 会在其局部 cfg
% 副本中补齐它们，并把补齐后的配置保存到 problem.cfg。
%
% MATLAB 函数参数采用值传递语义，因此调用 make_problem(env,cfg) 后，外层
% 变量 cfg 仍保留空参考值。用户若直接调用 evaluate_path(z,env,cfg,...)
% 而不是调用 problem.evaluate(z)，评价器必须使用与 make_problem 完全相同
% 的规则补齐参考值，否则“标量 / []”会触发 MATLAB:dimagree。
%
% 本测试同时评价：
%   1) 未补齐参考值的原始 cfg；
%   2) make_problem 已补齐参考值的 problem.cfg。
% 两者必须得到一致的综合目标和子目标归一化结果。

% 使用固定随机种子，保证构造式样本在重复测试中完全一致。
rng(90210, 'twister');

% 创建完整默认配置。
cfg = default_config();

% 减少内部控制点数量，以降低回归测试运行时间。
cfg.path.K = 5;

% 使用固定数量的轨迹采样点。
cfg.path.M = 100;

% 关闭自适应采样，使两次评价具有完全相同的离散轨迹点集合。
cfg.path.enableAdaptiveSampling = false;

% 构建固定种子的基础合成山地环境。
env = build_synthetic_environment(cfg, 1, 90210);

% 创建统一问题接口；该步骤会在 problem.cfg 中补齐两个任务相关参考值。
problem = make_problem(env, cfg);

% 确认外层原始 cfg 的参考长度仍为空，验证测试确实覆盖 MATLAB 值传递情形。
assert(isempty(cfg.objective.norm.referenceLength), ...
    'The outer cfg should remain unchanged after make_problem.');

% 确认外层原始 cfg 的参考时间仍为空。
assert(isempty(cfg.objective.norm.referenceTime), ...
    'The outer cfg referenceTime should remain empty after make_problem.');

% 使用统一问题结构生成一个符合地形高度先验的归一化决策样本。
z = constructive_global_sample(problem);

% 使用仍含空参考值的原始 cfg 直接调用评价器。
rawCfgResult = evaluate_path(z, env, cfg, ...
    problem.physicalLB, problem.physicalUB);

% 使用 make_problem 已补齐参考值的冻结配置再次评价同一条路径。
frozenCfgResult = evaluate_path(z, env, problem.cfg, ...
    problem.physicalLB, problem.physicalUB);

% 两次评价均应正常结束，不能出现维度不一致或非法结果。
assert(strcmp(rawCfgResult.status, 'ok') && ...
    strcmp(frozenCfgResult.status, 'ok'), ...
    'Both raw-cfg and frozen-cfg evaluations must complete successfully.');

% 计算综合目标差的相对容差尺度。
objectiveScale = max([1, abs(rawCfgResult.F), abs(frozenCfgResult.F)]);

% 原始 cfg 的自动补齐结果必须与 problem.cfg 的冻结结果数值一致。
assert(abs(rawCfgResult.F - frozenCfgResult.F) <= 1e-12 * objectiveScale, ...
    'Automatic normalization resolution changed the objective definition.');

% 长度无量纲目标必须一致。
assert(abs(rawCfgResult.cost.normalized.length - ...
    frozenCfgResult.cost.normalized.length) <= 1e-12, ...
    'Normalized length differs between raw cfg and frozen cfg.');

% 时间无量纲目标必须一致。
assert(abs(rawCfgResult.cost.normalized.time - ...
    frozenCfgResult.cost.normalized.time) <= 1e-12, ...
    'Normalized time differs between raw cfg and frozen cfg.');
end
