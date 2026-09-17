function stats = init_strategy_stats(cfg)
%INIT_STRATEGY_STATS 初始化三个能量阶段相互独立的策略统计。

% 创建总统计结构。
stats = struct();

% 探索阶段包含团队成员、高树和多场景三个策略。
stats.exp = make_group({'team', 'tree', 'multi'}, ...
    cfg.strategy.pMinExploration);

% 开发高能量阶段包含围攻和快速俯冲两个策略。
stats.high = make_group({'siege', 'dive'}, cfg.strategy.pMinPair);

% 开发低能量阶段包含高地和围猎两个策略。
stats.low = make_group({'highground', 'encircle'}, cfg.strategy.pMinPair);
end

function group = make_group(names, minimumProbability)
%MAKE_GROUP 创建一个阶段的策略统计结构。

% 取得当前阶段策略数量。
numberOfStrategies = numel(names);

% 创建阶段统计结构。
group = struct();

% 保存固定策略名称顺序。
group.names = names;

% 将所有策略初始 Q 值设为中性零值。
group.Q = zeros(1, numberOfStrategies);

% 将所有策略初始调用次数设为零。
group.calls = zeros(1, numberOfStrategies);

% 将所有策略初始成功替换次数设为零。
group.successes = zeros(1, numberOfStrategies);

% 将所有策略初始可行跃迁次数设为零。
group.feasibleCrossings = zeros(1, numberOfStrategies);

% 将所有策略初始 FE 成本设为零。
group.totalFEs = zeros(1, numberOfStrategies);

% 为每个策略创建独立的近期奖励元胞。
group.recentRewards = cell(1, numberOfStrategies);

% 保存当前阶段每个策略的概率下限。
group.pMin = minimumProbability;

% 初始概率均匀分配。
group.probabilities = ones(1, numberOfStrategies) / numberOfStrategies;
end
