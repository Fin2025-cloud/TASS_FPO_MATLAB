function key = get_strategy_group(stage)
%GET_STRATEGY_GROUP 将阶段名称映射到统计结构字段。
switch lower(stage)
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case {'exploration','exp'}
        % [逐行说明] 计算或更新 `key`，供后续算法、评价或日志步骤使用。
        key='exp';
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case {'development_high','high'}
        % [逐行说明] 计算或更新 `key`，供后续算法、评价或日志步骤使用。
        key='high';
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case {'development_low','low'}
        % [逐行说明] 计算或更新 `key`，供后续算法、评价或日志步骤使用。
        key='low';
    % [逐行说明] 处理 switch 中未显式列出的其他取值。
    otherwise
        % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
        error('get_strategy_group:UnknownStage','Unknown stage: %s',stage);
end
end
