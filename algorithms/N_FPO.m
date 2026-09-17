function [bestCost,bestZ,convergence,output] = N_FPO(problem,userOpts)
%N_FPO 数值稳定化 FPO：不含 TAI、ASA、CDR 和停滞重置。
%
% 保留稳定锚点、逐维对称方向、反射边界、Deb 规则和 MaxFEs 停止，
% 用于判断单纯数值稳定化的贡献。
if nargin<2, userOpts=struct(); end
% [逐行说明] 计算或更新 `opts`，供后续算法、评价或日志步骤使用。
opts=merge_structs(problem.cfg,userOpts);
% [逐行说明] 计算或更新 `opts.initialization.enabled`，供后续算法、评价或日志步骤使用。
opts.initialization.enabled=false;
% [逐行说明] 计算或更新 `opts.strategy.enabled`，供后续算法、评价或日志步骤使用。
opts.strategy.enabled=false;
% [逐行说明] 计算或更新 `opts.repair.enabled`，供后续算法、评价或日志步骤使用。
opts.repair.enabled=false;
% [逐行说明] 计算或更新 `opts.stagnation.enabled`，供后续算法、评价或日志步骤使用。
opts.stagnation.enabled=false;
% [逐行说明] 计算或更新 `[bestCost,bestZ,convergence,output]`，供后续算法、评价或日志步骤使用。
[bestCost,bestZ,convergence,output]=TAAS_FPO(problem,opts);
% [逐行说明] 计算或更新 `output.variant`，供后续算法、评价或日志步骤使用。
output.variant='N-FPO';
end
