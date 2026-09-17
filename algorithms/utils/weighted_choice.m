function idx = weighted_choice(prob)
%WEIGHTED_CHOICE 按给定离散概率向量抽样一个索引。
prob = prob(:)';
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
prob(~isfinite(prob) | prob < 0) = 0;
% [逐行说明] 计算或更新 `s`，供后续算法、评价或日志步骤使用。
s = sum(prob);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if s <= 0
    % [逐行说明] 计算或更新 `prob`，供后续算法、评价或日志步骤使用。
    prob = ones(size(prob)) / numel(prob);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `prob`，供后续算法、评价或日志步骤使用。
    prob = prob / s;
end
% [逐行说明] 计算或更新 `u`，供后续算法、评价或日志步骤使用。
u = rand;
% [逐行说明] 计算或更新 `c`，供后续算法、评价或日志步骤使用。
c = cumsum(prob);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
idx = find(u <= c, 1, 'first');
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(idx)
    % [逐行说明] 计算或更新 `idx`，供后续算法、评价或日志步骤使用。
    idx = numel(prob);
end
end
