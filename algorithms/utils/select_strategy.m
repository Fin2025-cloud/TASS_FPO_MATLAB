function [index, name, stats, probabilities] = select_strategy(stats, stage, cfg)
%SELECT_STRATEGY 在当前能量阶段内选择一个 FPO 策略。
%
% 预热阶段优先选择调用次数最少的策略，确保每个策略都有最低观测样本；
% 完成预热后根据带概率下限的 softmax 进行随机选择。该函数只更新保存的
% 当前概率，不更新 Q、奖励或成功次数。

% 将阶段名称映射为 exp、high 或 low 统计分组键。
groupKey = get_strategy_group(stage);

% 读取当前阶段策略统计结构。
group = stats.(groupKey);

% 根据当前 Q 值计算策略概率。
probabilities = strategy_probabilities(group, cfg);

% 判断是否启用自适应策略选择。
if cfg.strategy.enabled
    % 找出调用次数尚低于预热要求的策略。
    underused = find(group.calls < cfg.strategy.warmupCalls);

    % 若仍有策略未完成预热，则优先在其中选择。
    if ~isempty(underused)
        % 取得未完成预热策略中的最小调用次数。
        minimumCalls = min(group.calls(underused));

        % 找出所有并列最少调用的策略。
        pool = underused(group.calls(underused) == minimumCalls);
        probabilities=zeros(size(probabilities));
        probabilities(pool)=1/numel(pool); % log the actual warm-up distribution

        % 在并列策略中均匀随机选择，避免固定顺序偏差。
        index = pool(randi(numel(pool)));
    else
        % 完成预热后按照学习概率进行加权随机选择。
        index = weighted_choice(probabilities);
    end
else
    % 关闭自适应时，在当前阶段策略间均匀随机选择。
    index = randi(numel(group.names));
end

% 根据索引取得策略名称。
name = group.names{index};

% 保存本次使用的概率向量，便于日志记录。
group.probabilities = probabilities;

% 将更新后的阶段统计结构写回总统计。
stats.(groupKey) = group;
end
