function x = reflect_bounds(x, lb, ub)
%REFLECT_BOUNDS 将越界变量通过镜像反射映射回 [lb,ub]。
%
% 与直接 clip 相比，反射不会把大量个体永久压在边界上，并保留了越界
% 位移的部分方向信息。函数支持标量或与 x 同尺寸的上下界。
%
% 对于跨度为零的维度，直接固定为 lb。

% [逐行说明] 计算或更新 `x`，供后续算法、评价或日志步骤使用。
x = double(x);
% [逐行说明] 计算或更新 `lb`，供后续算法、评价或日志步骤使用。
lb = expand_to_size(lb, size(x));
% [逐行说明] 计算或更新 `ub`，供后续算法、评价或日志步骤使用。
ub = expand_to_size(ub, size(x));
% [逐行说明] 计算或更新 `span`，供后续算法、评价或日志步骤使用。
span = ub - lb;
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
fixed = span <= 0;
% [逐行说明] 计算或更新 `span(fixed)`，供后续算法、评价或日志步骤使用。
span(fixed) = 1;

% 将任意实数先平移到以 0 为起点的周期区间，再做三角波反射。
y = mod(x - lb, 2 .* span);
% [逐行说明] 计算或更新 `y`，供后续算法、评价或日志步骤使用。
y = span - abs(y - span);
% [逐行说明] 计算或更新 `x`，供后续算法、评价或日志步骤使用。
x = lb + y;
% [逐行说明] 计算或更新 `x(fixed)`，供后续算法、评价或日志步骤使用。
x(fixed) = lb(fixed);
end

function a = expand_to_size(a, targetSize)
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isscalar(a)
    % [逐行说明] 计算或更新 `a`，供后续算法、评价或日志步骤使用。
    a = repmat(a, targetSize);
% [逐行说明] 在前一条件不成立时继续判断当前条件。
elseif isvector(a) && numel(a) == targetSize(end)
    % [逐行说明] 计算或更新 `a`，供后续算法、评价或日志步骤使用。
    a = repmat(reshape(a, 1, []), targetSize(1), 1);
% [逐行说明] 在前一条件不成立时继续判断当前条件。
elseif ~isequal(size(a), targetSize)
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('reflect_bounds:SizeMismatch', 'Bounds are incompatible with x.');
end
end
