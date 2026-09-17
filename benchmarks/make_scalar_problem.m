function problem = make_scalar_problem(fobj,lbPhysical,ubPhysical,dim,cfg,name)
%MAKE_SCALAR_PROBLEM 将任意标量最小化函数包装为 ASA-FPO 的统一接口。
%
% 优化器始终在 [0,1]^D 中运行，评价时映射到原测试函数物理边界。
% CEC 实验必须调用官方 CEC 函数/数据；本函数不包含、修改或伪造 CEC 数据。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<5 || isempty(cfg), cfg=default_config(); end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
validate_config(cfg);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<6 || isempty(name), name='scalar_problem'; end
% [逐行说明] 计算或更新 `lbPhysical`，供后续算法、评价或日志步骤使用。
lbPhysical=expand(lbPhysical,dim);
% [逐行说明] 计算或更新 `ubPhysical`，供后续算法、评价或日志步骤使用。
ubPhysical=expand(ubPhysical,dim);
% [逐行说明] 计算或更新 `problem`，供后续算法、评价或日志步骤使用。
problem=struct();
% [逐行说明] 计算或更新 `problem.name`，供后续算法、评价或日志步骤使用。
problem.name=name;
% [逐行说明] 计算或更新 `problem.kind`，供后续算法、评价或日志步骤使用。
problem.kind='scalar';
% [逐行说明] 计算或更新 `problem.dim`，供后续算法、评价或日志步骤使用。
problem.dim=dim;
% [逐行说明] 计算或更新 `problem.lb`，供后续算法、评价或日志步骤使用。
problem.lb=zeros(1,dim);
% [逐行说明] 计算或更新 `problem.ub`，供后续算法、评价或日志步骤使用。
problem.ub=ones(1,dim);
% [逐行说明] 计算或更新 `problem.physicalLB`，供后续算法、评价或日志步骤使用。
problem.physicalLB=lbPhysical;
% [逐行说明] 计算或更新 `problem.physicalUB`，供后续算法、评价或日志步骤使用。
problem.physicalUB=ubPhysical;
% [逐行说明] 计算或更新 `problem.cfg`，供后续算法、评价或日志步骤使用。
problem.cfg=cfg;
% [逐行说明] 计算或更新 `problem.evaluate`，供后续算法、评价或日志步骤使用。
problem.evaluate=@evaluate;
% [逐行说明] 计算或更新 `problem.repair`，供后续算法、评价或日志步骤使用。
problem.repair=@no_repair;
% [逐行说明] 计算或更新 `problem.initializer`，供后续算法、评价或日志步骤使用。
problem.initializer=@random_initializer;

    function r=evaluate(z)
        % [逐行说明] 计算或更新 `x`，供后续算法、评价或日志步骤使用。
        x=lbPhysical+z(:)'.*(ubPhysical-lbPhysical);
        % [逐行说明] 计算或更新 `F`，供后续算法、评价或日志步骤使用。
        F=fobj(x);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if ~isscalar(F)||~isfinite(F)
            % [逐行说明] 计算或更新 `F`，供后续算法、评价或日志步骤使用。
            F=realmax/100;
        end
        % [逐行说明] 计算或更新 `r`，供后续算法、评价或日志步骤使用。
        r=result_stub(F,0);
        % [逐行说明] 计算或更新 `r.isFeasible`，供后续算法、评价或日志步骤使用。
        r.isFeasible=true;
        % [逐行说明] 计算或更新 `r.z`，供后续算法、评价或日志步骤使用。
        r.z=z(:)';
        % [逐行说明] 计算或更新 `r.x`，供后续算法、评价或日志步骤使用。
        r.x=x;
        % [逐行说明] 计算或更新 `r.cost`，供后续算法、评价或日志步骤使用。
        r.cost=struct('total',F);
        % [逐行说明] 计算或更新 `r.violation`，供后续算法、评价或日志步骤使用。
        r.violation=struct('total',0,'raw',struct(),'normalized',struct());
        % [逐行说明] 计算或更新 `r.status`，供后续算法、评价或日志步骤使用。
        r.status='ok';
    end

    function [z,info]=no_repair(varargin) %#ok<INUSD>
        % [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
        z=zeros(0,dim); info=struct('actions',{{}},'success',false,'rounds',0);
    end

    function [X,meta]=random_initializer(N,isRestart) %#ok<INUSD>
        % [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
        X=rand(N,dim); meta=struct('source',repmat("random",N,1),'isRestart',isRestart);
    end
end

function b=expand(b,dim)
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isscalar(b), b=repmat(b,1,dim); else, b=reshape(b,1,[]); end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if numel(b)~=dim, error('make_scalar_problem:Bounds','Bound length mismatch.'); end
end
