function stats = update_strategy_stats(stats, stage, strategyIndex, reward, ...
    success, numberOfFEs, crossedToFeasible, cfg)
%UPDATE_STRATEGY_STATS 更新阶段内策略调用、奖励窗口和 Q 值。
%
% 统计内容包括调用次数、成功替换次数、不可行到可行跃迁次数、实际 FE 成本、
% 最近奖励窗口和指数平滑 Q。未被调用策略的 Q 缓慢回归中性先验，避免陈旧
% 高 Q 在长时间未使用后仍永久占优。

% 将阶段名称转换为统计分组键。
groupKey = get_strategy_group(stage);

% 读取当前阶段统计结构。
group = stats.(groupKey);

% 取得当前阶段策略数量。
numberOfStrategies = numel(group.names);

% 对本次未调用策略执行轻微先验回归。
for k = 1:numberOfStrategies
    % 仅处理未被选中的策略。
    if k ~= strategyIndex
        % 以 unusedDecay 为步长把 Q 拉向 qPrior。
        group.Q(k) = (1 - cfg.strategy.unusedDecay) * group.Q(k) + ...
            cfg.strategy.unusedDecay * cfg.strategy.qPrior;
    end
end

% 增加被选策略的调用次数。
group.calls(strategyIndex) = group.calls(strategyIndex) + 1;

% 根据是否替换当前个体增加成功次数。
group.successes(strategyIndex) = group.successes(strategyIndex) + double(success);

% 根据是否完成不可行到可行跃迁增加计数。
group.feasibleCrossings(strategyIndex) = ...
    group.feasibleCrossings(strategyIndex) + double(crossedToFeasible);

% 累加该策略实际消耗的函数评价次数。
group.totalFEs(strategyIndex) = ...
    group.totalFEs(strategyIndex) + numberOfFEs;

% 读取该策略现有的近期奖励序列。
recent = group.recentRewards{strategyIndex};

% 将本次奖励追加到序列末尾。
recent = [recent, reward]; %#ok<AGROW>

% 若序列超过滑动窗口长度，只保留最近若干项。
if numel(recent) > cfg.strategy.window
    % 截取窗口尾部。
    recent = recent(end - cfg.strategy.window + 1:end);
end

% 保存截断后的奖励窗口。
group.recentRewards{strategyIndex} = recent;

% 计算当前滑动窗口平均奖励。
windowMean = mean(recent);

% 用 rho 对被调用策略的 Q 值执行指数平滑更新。
group.Q(strategyIndex) = (1 - cfg.strategy.rho) * ...
    group.Q(strategyIndex) + cfg.strategy.rho * windowMean;

% 根据更新后的 Q 值重新计算当前概率。
group.probabilities = strategy_probabilities(group, cfg);

% 将当前阶段统计结构写回总统计。
stats.(groupKey) = group;
end
