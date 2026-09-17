function probabilities = strategy_probabilities(group, cfg)
%STRATEGY_PROBABILITIES 计算带概率下限的数值稳定 softmax。
%
% p_k = p_min + (1-K*p_min) * exp(Q_k/tau)/sum_j exp(Q_j/tau)。
% 概率下限保证任何策略不会永久消失；减去 max(Q) 防止指数溢出。

% 取得当前阶段可选策略数量。
numberOfStrategies = numel(group.names);

% 当自适应策略学习关闭时，使用严格均匀概率。
if ~cfg.strategy.enabled
    % 为每个策略分配 1/K 概率。
    probabilities = ones(1, numberOfStrategies) / numberOfStrategies;

    % 结束函数。
    return;
end

% 把 Q 值平移，使最大值为零，提高指数计算稳定性。
if isfield(cfg.strategy,'selector') && strcmp(cfg.strategy.selector,'probability_matching')
    quality=max(group.Q,0);
    if sum(quality)<=eps,quality=ones(size(quality));end
    probabilities=group.pMin+(1-numberOfStrategies*group.pMin)*quality/sum(quality);
    probabilities=probabilities/sum(probabilities);
    return;
end
shiftedQ = group.Q - max(group.Q);

% 除以不小于 eps 的 softmax 温度。
scaledQ = shiftedQ / max(cfg.strategy.temperature, eps);

% 计算未归一化指数权重。
exponentialWeight = exp(scaledQ);

% 归一化得到普通 softmax 概率。
softmaxProbability = exponentialWeight / (sum(exponentialWeight) + eps);

% 加入每个策略的最小概率下限。
probabilities = group.pMin + ...
    (1 - numberOfStrategies * group.pMin) .* softmaxProbability;

% 消除浮点误差导致的极小负值。
probabilities = max(probabilities, 0);

% 再次归一化，使概率和严格接近 1。
probabilities = probabilities / sum(probabilities);
end
