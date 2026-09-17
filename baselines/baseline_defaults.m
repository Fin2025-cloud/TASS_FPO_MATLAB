function opts = baseline_defaults(problem,userOpts)
%BASELINE_DEFAULTS 统一基线算法配置。
if nargin<2, userOpts=struct(); end
% [逐行说明] 计算或更新 `opts`，供后续算法、评价或日志步骤使用。
opts=merge_structs(problem.cfg,userOpts);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
validate_config(opts);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts,'baseline'), opts.baseline=struct(); end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'useTAI'), opts.baseline.useTAI=false; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'useRepair'), opts.baseline.useRepair=false; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'inertia'), opts.baseline.inertia=0.729; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'c1'), opts.baseline.c1=1.49445; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'c2'), opts.baseline.c2=1.49445; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'DE_F'), opts.baseline.DE_F=0.5; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(opts.baseline,'DE_CR'), opts.baseline.DE_CR=0.9; end
end
