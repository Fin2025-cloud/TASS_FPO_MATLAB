function test_reproducibility_small()
%TEST_REPRODUCIBILITY_SMALL 验证相同算法种子产生完全相同的小预算搜索结果。
%
% 本测试覆盖：地形感知初始化、A* 种子、Tent 扰动、候选生成、修复、策略
% 选择和停滞逻辑。比较内容只包括确定性的数值结果，不比较 runtime 或时间戳。

% 创建默认配置。
cfg = default_config();

% 使用较小种群以缩短回归测试时间。
cfg.algorithm.N = 10;

% 使用较小但足以越过初始化阶段的 FE 预算。
cfg.algorithm.MaxFEs = 180;

% 固定算法随机种子，要求两次运行随机流完全相同。
cfg.algorithm.seed = 99;

% 使用 5 个内部控制点降低决策维数。
cfg.path.K = 5;

% 使用 80 个初始轨迹采样点。
cfg.path.M = 80;

% 限制自适应采样点数，降低单元测试耗时。
cfg.path.maxAdaptivePoints = 120;

% 使用较小 A* 网格，仍保留多通道初始化逻辑。
cfg.initialization.gridSize = [25, 25];

% 关闭命令行迭代输出，避免测试日志冗余。
cfg.algorithm.verbose = false;

% 保持算法内部不变量检查开启。
cfg.algorithm.assertInvariants = true;

% 用固定场景种子构建完全一致的环境。
env = build_synthetic_environment(cfg, 1, 888);

% 封装统一优化问题。
problem = make_problem(env, cfg);

% 第一次运行完整 TAAS-FPO。
[f1, z1, convergence1, output1] = TAAS_FPO(problem, cfg);

% 第二次使用同一问题与同一算法种子重新运行 TAAS-FPO。
[f2, z2, convergence2, output2] = TAAS_FPO(problem, cfg);

% 两次运行的最终综合目标必须逐位完全一致。
assert(isequaln(f1, f2), 'Best objective differs under the same seed.');

% 两次运行的最终归一化最优位置必须逐位完全一致。
assert(isequaln(z1, z2), 'Best position differs under the same seed.');

% 两次运行记录的 FE 横轴必须完全一致。
assert(isequaln(convergence1.FE, convergence2.FE), ...
    'FE logging differs under the same seed.');

% 两次运行的实际 FE 总数必须相同。
assert(output1.actualFEs == output2.actualFEs, ...
    'Actual FE totals differ under the same seed.');

% 两次运行的最终约束违反度必须完全一致。
assert(isequaln(output1.bestResult.CV, output2.bestResult.CV), ...
    'Best constraint violation differs under the same seed.');
end
