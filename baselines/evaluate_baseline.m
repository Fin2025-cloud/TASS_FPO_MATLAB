function bundle = evaluate_baseline(z,currentResult,problem,opts,remaining)
%EVALUATE_BASELINE 统一基线候选评价；默认不使用 TAAS 专用修复。
local=opts;
% [逐行说明] 计算或更新 `local.repair.enabled`，供后续算法、评价或日志步骤使用。
local.repair.enabled=opts.baseline.useRepair;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if opts.baseline.useRepair
    % [逐行说明] 计算或更新 `rounds`，供后续算法、评价或日志步骤使用。
    rounds=opts.repair.maxRounds;
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `rounds`，供后续算法、评价或日志步骤使用。
    rounds=0;
end
% [逐行说明] 计算或更新 `bundle`，供后续算法、评价或日志步骤使用。
bundle=evaluate_with_repair(z,currentResult,problem,local,remaining,rounds);
end
