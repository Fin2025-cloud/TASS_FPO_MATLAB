function [bestCost,bestZ,convergence,output] = ASA_FPO(problem,userOpts)
%ASA_FPO 自适应策略 FPO：启用 ASA/停滞恢复，关闭路径专用 TAI 与 CDR。
%
% 该版本适用于 CEC 或“纯优化器公平线”实验。对于 CEC，problem 应由
% make_scalar_problem 构造，且不得调用任何路径专用评价或修复。
if nargin<2, userOpts=struct(); end
% [逐行说明] 计算或更新 `opts`，供后续算法、评价或日志步骤使用。
opts=merge_structs(problem.cfg,userOpts);
% [逐行说明] 计算或更新 `opts.initialization.enabled`，供后续算法、评价或日志步骤使用。
opts.initialization.enabled=false;
% [逐行说明] 计算或更新 `opts.strategy.enabled`，供后续算法、评价或日志步骤使用。
opts.strategy.enabled=true;
% [逐行说明] 计算或更新 `opts.repair.enabled`，供后续算法、评价或日志步骤使用。
opts.repair.enabled=false;
% [逐行说明] 计算或更新 `opts.stagnation.enabled`，供后续算法、评价或日志步骤使用。
opts.stagnation.enabled=true;
% [逐行说明] 计算或更新 `[bestCost,bestZ,convergence,output]`，供后续算法、评价或日志步骤使用。
[bestCost,bestZ,convergence,output]=TAAS_FPO(problem,opts);
% [逐行说明] 计算或更新 `output.variant`，供后续算法、评价或日志步骤使用。
output.variant='ASA-FPO';
end
