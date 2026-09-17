function r = result_stub(F, CV)
%RESULT_STUB 创建最小结果结构，供标量基准函数和单元测试使用。
if nargin < 1, F = inf; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin < 2, CV = inf; end
% [逐行说明] 计算或更新 `r`，供后续算法、评价或日志步骤使用。
r = struct();
% [逐行说明] 计算或更新 `r.F`，供后续算法、评价或日志步骤使用。
r.F = F;
% [逐行说明] 计算或更新 `r.CV`，供后续算法、评价或日志步骤使用。
r.CV = CV;
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
r.isFeasible = isfinite(F) && CV <= 0;
% [逐行说明] 计算或更新 `r.cost`，供后续算法、评价或日志步骤使用。
r.cost = struct('total', F);
% [逐行说明] 计算或更新 `r.violation`，供后续算法、评价或日志步骤使用。
r.violation = struct('total', CV);
end
