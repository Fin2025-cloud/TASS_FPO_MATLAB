function test_energy_direction()
%TEST_ENERGY_DIRECTION 验证风向对空速和旋翼能耗的物理方向影响。
%
% 在固定地速条件下，同一条空间路径满足：
%   逆风空速 > 无风空速 > 顺风空速；
% 因此旋翼解析 B 模型应至少满足：
%   逆风总能耗 > 顺风总能耗。
% 本测试只检查方向关系，不把默认模型参数当作真实平台标定结果。

% 创建完整默认配置。
cfg = default_config();

% 将内部控制点数量减小到 5，加快单元测试。
cfg.path.K = 5;

% 使用 120 个均匀采样点，足以验证能耗方向。
cfg.path.M = 120;

% 关闭自适应采样，使三次评价使用完全相同的采样参数集合。
cfg.path.enableAdaptiveSampling = false;

% 强制使用旋翼解析 B 级能耗模型。
cfg.energy.model = 'B';

% 使用固定场景种子构建基础合成环境。
env = build_synthetic_environment(cfg, 1, 321);

% 将环境和配置封装为统一问题接口。
problem = make_problem(env, cfg);

% 生成沿任务方向、满足地形高度先验的构造式决策样本。
z = constructive_global_sample(problem);

% 把环境风场设置为零风。
env.wind = struct('type', 'constant', 'constant', [0, 0, 0]);

% 在零风下评价同一条路径。
r0 = evaluate_path(z, env, cfg, problem.physicalLB, problem.physicalUB);

% 计算从起点指向终点的三维任务方向。
flightDirection = env.goal - env.start;

% 把任务方向归一化为单位向量。
flightDirection = flightDirection / max(norm(flightDirection), eps);

% 设置与飞行方向相反的 6 m/s 常风，形成逆风。
env.wind.constant = -6 .* flightDirection;

% 在逆风下评价同一条空间路径。
rHeadwind = evaluate_path(z, env, cfg, problem.physicalLB, problem.physicalUB);

% 设置与飞行方向一致的 6 m/s 常风，形成顺风。
env.wind.constant = 6 .* flightDirection;

% 在顺风下评价同一条空间路径。
rTailwind = evaluate_path(z, env, cfg, problem.physicalLB, problem.physicalUB);

% 检查三个评价结果都正常完成，避免在异常结果上比较 Inf。
assert(strcmp(r0.status, 'ok') && strcmp(rHeadwind.status, 'ok') && ...
    strcmp(rTailwind.status, 'ok'), ...
    'Energy direction test received an invalid path evaluation.');

% 逆风下的总推进能耗必须高于顺风下的总推进能耗。
assert(rHeadwind.cost.energy > rTailwind.cost.energy, ...
    'Headwind energy must be greater than tailwind energy.');

% 逆风下的最大空速必须高于顺风下的最大空速。
assert(rHeadwind.maxAirSpeed > rTailwind.maxAirSpeed, ...
    'Headwind maximum airspeed must be greater than tailwind maximum airspeed.');

% 零风能耗必须是有限实数。
assert(isfinite(r0.cost.energy), 'No-wind energy must be finite.');
end
