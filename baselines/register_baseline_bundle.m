function [FEs,firstFeasibleFE] = register_baseline_bundle(bundle,FEs,firstFeasibleFE)
%REGISTER_BASELINE_BUNDLE 按评价顺序登记基线算法 FE 和首次可行位置。
startFE=FEs;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isnan(firstFeasibleFE)
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for k=1:numel(bundle.evalResults)
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if bundle.evalResults{k}.isFeasible
            % [逐行说明] 计算或更新 `firstFeasibleFE`，供后续算法、评价或日志步骤使用。
            firstFeasibleFE=startFE+k;
            % [逐行说明] 提前结束当前循环。
            break;
        end
    end
end
% [逐行说明] 计算或更新 `FEs`，供后续算法、评价或日志步骤使用。
FEs=startFE+bundle.nFE;
end
