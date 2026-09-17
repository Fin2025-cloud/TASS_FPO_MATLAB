function step = levy_flight(n, dim, beta)
%LEVY_FLIGHT 使用 Mantegna 方法生成 Lévy 稳定分布步长。
%
% 输入：
%   n    - 样本数
%   dim  - 维度
%   beta - 稳定指数，推荐 1.3~1.6
%
% 输出 step 为 n×dim。函数只使用 randn 和 gamma，不依赖统计工具箱。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin < 3 || isempty(beta)
    % [逐行说明] 计算或更新 `beta`，供后续算法、评价或日志步骤使用。
    beta = 1.5;
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if beta <= 1 || beta >= 2
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('levy_flight:BetaRange', 'beta must be in (1,2).');
end
% [逐行说明] 计算或更新 `sigmaU`，供后续算法、评价或日志步骤使用。
sigmaU = (gamma(1 + beta) * sin(pi * beta / 2) / ...
    (gamma((1 + beta) / 2) * beta * 2^((beta - 1) / 2)))^(1 / beta);
% [逐行说明] 计算或更新 `u`，供后续算法、评价或日志步骤使用。
u = sigmaU .* randn(n, dim);
% [逐行说明] 计算或更新 `v`，供后续算法、评价或日志步骤使用。
v = randn(n, dim);
% [逐行说明] 计算或更新 `step`，供后续算法、评价或日志步骤使用。
step = u ./ (abs(v).^(1 / beta) + eps);
end
