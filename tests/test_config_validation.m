function test_config_validation()
%TEST_CONFIG_VALIDATION 确认正式配置检查不会静默改写非法参数。
cfg=default_config();
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
validate_config(cfg);

% [逐行说明] 计算或更新 `bad`，供后续算法、评价或日志步骤使用。
bad=cfg;
% [逐行说明] 计算或更新 `bad.objective.weights.length`，供后续算法、评价或日志步骤使用。
bad.objective.weights.length=0.50; % 此时权重和不再为 1
% [逐行说明] 计算或更新 `caught`，供后续算法、评价或日志步骤使用。
caught=false;
% [逐行说明] 开始受保护执行区，用于捕获运行异常。
try
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    validate_config(bad);
% [逐行说明] 捕获前述受保护执行区产生的异常。
catch ME
    % [逐行说明] 计算或更新 `caught`，供后续算法、评价或日志步骤使用。
    caught=strcmp(ME.identifier,'validate_config:ObjectiveWeights');
end
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(caught,'Invalid objective weights were not rejected.');

% [逐行说明] 计算或更新 `bad`，供后续算法、评价或日志步骤使用。
bad=cfg;
% [逐行说明] 计算或更新 `bad.strategy.pMinExploration`，供后续算法、评价或日志步骤使用。
bad.strategy.pMinExploration=0.34;
% [逐行说明] 计算或更新 `caught`，供后续算法、评价或日志步骤使用。
caught=false;
% [逐行说明] 开始受保护执行区，用于捕获运行异常。
try
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    validate_config(bad);
% [逐行说明] 捕获前述受保护执行区产生的异常。
catch ME
    % [逐行说明] 计算或更新 `caught`，供后续算法、评价或日志步骤使用。
    caught=strcmp(ME.identifier,'validate_config:PMinExploration');
end
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(caught,'Invalid strategy probability floor was not rejected.');
end
