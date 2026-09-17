function probabilities = all_strategy_probabilities(stats, cfg)
%ALL_STRATEGY_PROBABILITIES 按固定顺序返回七种策略的当前概率。
%
% 固定顺序为：team、tree、multi、siege、dive、highground、encircle。
% 三个阶段概率分别归一化，因此七个数的总和不是 1；日志绘图应按阶段解读。

% 计算探索阶段三个策略概率。
explorationProbability = strategy_probabilities(stats.exp, cfg);

% 计算开发高能量阶段两个策略概率。
highDevelopmentProbability = strategy_probabilities(stats.high, cfg);

% 计算开发低能量阶段两个策略概率。
lowDevelopmentProbability = strategy_probabilities(stats.low, cfg);

% 按固定顺序拼接七个概率。
probabilities = [explorationProbability, highDevelopmentProbability, ...
    lowDevelopmentProbability];
end
