function out = merge_structs(base, override)
%MERGE_STRUCTS 递归合并两个结构体。
% override 中出现的字段覆盖 base；嵌套结构体递归处理。
%
% 该函数用于在保持默认配置完整性的同时，只修改少量参数。

% [逐行说明] 计算或更新 `out`，供后续算法、评价或日志步骤使用。
out = base;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(override)
    % [逐行说明] 结束当前函数并把已计算结果返回调用方。
    return;
end
% [逐行说明] 计算或更新 `names`，供后续算法、评价或日志步骤使用。
names = fieldnames(override);
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i = 1:numel(names)
    % [逐行说明] 计算或更新 `name`，供后续算法、评价或日志步骤使用。
    name = names{i};
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if isfield(out, name) && isstruct(out.(name)) && isstruct(override.(name))
        % [逐行说明] 计算或更新 `out.(name)`，供后续算法、评价或日志步骤使用。
        out.(name) = merge_structs(out.(name), override.(name));
    % [逐行说明] 处理前述条件均不成立的情况。
    else
        % [逐行说明] 计算或更新 `out.(name)`，供后续算法、评价或日志步骤使用。
        out.(name) = override.(name);
    end
end
end
