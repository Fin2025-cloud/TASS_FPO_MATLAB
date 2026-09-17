function [fobj,lb,ub,name] = basic_benchmark(id)
%BASIC_BENCHMARK 提供仅用于代码单元测试的经典函数。
%
% 这些函数不是 CEC 测试集，不应在论文中替代官方 CEC 数据。
switch lower(string(id))
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case {"sphere","f1"}
        % [逐行说明] 计算或更新 `fobj`，供后续算法、评价或日志步骤使用。
        fobj=@(x) sum(x.^2); lb=-100; ub=100; name='Sphere';
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case {"rastrigin","f2"}
        % [逐行说明] 计算或更新 `fobj`，供后续算法、评价或日志步骤使用。
        fobj=@(x) 10*numel(x)+sum(x.^2-10*cos(2*pi*x)); lb=-5.12; ub=5.12; name='Rastrigin';
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case {"rosenbrock","f3"}
        % [逐行说明] 计算或更新 `fobj`，供后续算法、评价或日志步骤使用。
        fobj=@(x) sum(100*(x(2:end)-x(1:end-1).^2).^2+(x(1:end-1)-1).^2); lb=-30; ub=30; name='Rosenbrock';
    % [逐行说明] 处理 switch 中未显式列出的其他取值。
    otherwise
        % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
        error('basic_benchmark:Unknown','Unknown test function.');
end
end
