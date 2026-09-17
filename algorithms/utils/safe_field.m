function value = safe_field(s, name, defaultValue)
%SAFE_FIELD 若结构体中存在字段则返回，否则返回默认值。
if isstruct(s) && isfield(s, name)
    % [逐行说明] 计算或更新 `value`，供后续算法、评价或日志步骤使用。
    value = s.(name);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `value`，供后续算法、评价或日志步骤使用。
    value = defaultValue;
end
end
