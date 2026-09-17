function diversity = population_diversity(X)
%POPULATION_DIVERSITY 计算归一化种群相对中心的平均 L1 离散度。
%
% D_pop = (1/(N*D)) sum_i sum_d |X_{i,d}-mean_i(X_{i,d})|。
% 对位于 [0,1]^D 的种群，该值通常位于 [0,0.5]。它只用于停滞判断和日志，
% 不参与目标函数，也不会改变任何候选位置。

% 空种群没有可定义的离散程度。
if isempty(X)
    % 返回零作为防御性结果。
    diversity = 0;

    % 结束函数。
    return;
end

% 计算每个决策维度在整个种群中的均值，得到 1×D 中心向量。
center = mean(X, 1);

% 显式从每个个体中减去种群中心，避免隐式扩展版本差异。
deviation = bsxfun(@minus, X, center);

% 对全部个体和全部维度的绝对偏差取平均。
diversity = mean(abs(deviation(:)));
end
