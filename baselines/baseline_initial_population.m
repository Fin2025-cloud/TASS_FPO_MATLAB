function X = baseline_initial_population(problem,N,opts)
%BASELINE_INITIAL_POPULATION 按实验线选择随机或共享 TAI 初始化。
if opts.baseline.useTAI && isfield(problem,'initializer')
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    [X,~]=problem.initializer(N,false);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
    X=problem.lb+rand(N,problem.dim).*(problem.ub-problem.lb);
end
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=reflect_bounds(X,problem.lb,problem.ub);
end
