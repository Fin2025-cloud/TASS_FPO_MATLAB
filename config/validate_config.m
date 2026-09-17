function validate_config(cfg)
%VALIDATE_CONFIG 检查会影响实验真实性和数值稳定性的关键配置。
%
% 本函数只做检查，不自动“修正”参数。自动归一化权重、偷偷扩大预算或改变
% 非法阈值会让不同运行使用不同规则，因此检测到问题时直接报错，要求用户
% 在正式实验开始前明确修改并重新保存配置。

% [逐行说明] 计算或更新 `requiredTop`，供后续算法、评价或日志步骤使用。
requiredTop={'path','uav','constraint','objective','algorithm','strategy', ...
    'repair','initialization','stagnation','experiment'};
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:numel(requiredTop)
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if ~isfield(cfg,requiredTop{i})
        % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
        error('validate_config:MissingSection','Missing cfg.%s.',requiredTop{i});
    end
end

% 路径表示：三次 B 样条至少需要 4 个总控制点，即内部点 K>=2。
assert_integer(cfg.path.K,2,'cfg.path.K');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
assert_integer(cfg.path.M,cfg.path.K+2,'cfg.path.M');
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.path.splineDegree~=3
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:SplineDegree','Current decoder is implemented for cubic B-splines (degree=3).');
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.path.maxAdaptivePoints<cfg.path.M
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:AdaptivePoints','maxAdaptivePoints must be >= path.M.');
end

% 搜索预算与种群。
assert_integer(cfg.algorithm.N,3,'cfg.algorithm.N');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
assert_integer(cfg.algorithm.MaxFEs,cfg.algorithm.N,'cfg.algorithm.MaxFEs');
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.algorithm.logEveryFE<=0
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:LogInterval','algorithm.logEveryFE must be positive.');
end

% 目标权重必须预先固定且和为 1，防止不同脚本隐式采用不同尺度。
w=cfg.objective.weights;
% [逐行说明] 计算或更新 `wv`，供后续算法、评价或日志步骤使用。
wv=[w.length,w.energy,w.risk,w.smoothness,w.time];
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if any(~isfinite(wv))||any(wv<0)||abs(sum(wv)-1)>1e-10
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:ObjectiveWeights','Objective weights must be nonnegative and sum to 1.');
end

% 主要物理参数必须为正。
positiveValues=[cfg.uav.radius,cfg.uav.groundSpeed,cfg.uav.maxAirSpeed, ...
    cfg.uav.maxClimbAngle,cfg.uav.maxCurvature,cfg.uav.maxAcceleration, ...
    cfg.uav.mass,cfg.uav.batteryEnergy,cfg.constraint.clearance];
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if any(~isfinite(positiveValues))||any(positiveValues<=0)
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:PhysicalParameters','UAV/constraint physical parameters must be finite and positive.');
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~any(strcmpi(char(cfg.energy.model),{'A','B'}))
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:EnergyModel','cfg.energy.model must be ''A'' or ''B''.');
end

% 无量纲违反度尺度必须严格为正，否则某类约束会被除零或被错误忽略。
scaleNames=fieldnames(cfg.constraint.scale);
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:numel(scaleNames)
    % [逐行说明] 计算或更新 `value`，供后续算法、评价或日志步骤使用。
    value=cfg.constraint.scale.(scaleNames{i});
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if ~isscalar(value)||~isfinite(value)||value<=0
        % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
        error('validate_config:ViolationScale','constraint.scale.%s must be positive.',scaleNames{i});
    end
end

% TAI 三部分比例必须显式和为 1，不在运行时静默改写正式配置。
f=[cfg.initialization.seedFraction,cfg.initialization.localTentFraction, ...
    cfg.initialization.globalFraction];
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if any(~isfinite(f))||any(f<0)||abs(sum(f)-1)>1e-10
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:InitializationFractions', ...
        'TAI fractions must be nonnegative and sum to 1.');
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
assert_integer(cfg.initialization.numSeedPaths,1,'cfg.initialization.numSeedPaths');

% 概率下限必须给 softmax 留出正的自适应质量。
if cfg.strategy.pMinExploration<0||3*cfg.strategy.pMinExploration>=1
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:PMinExploration','pMinExploration must satisfy 0 <= 3*pMin < 1.');
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.strategy.pMinPair<0||2*cfg.strategy.pMinPair>=1
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:PMinPair','pMinPair must satisfy 0 <= 2*pMin < 1.');
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.strategy.temperature<=0||cfg.strategy.window<1||cfg.strategy.warmupCalls<0
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:StrategyParameters','Strategy temperature/window/warmup are invalid.');
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.strategy.lambdaRepair<0||cfg.strategy.lambdaRepair>1
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:RepairCredit','lambdaRepair must be in [0,1].');
end

% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
assert_integer(cfg.repair.maxRounds,0,'cfg.repair.maxRounds');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
assert_integer(cfg.repair.maxInitRounds,0,'cfg.repair.maxInitRounds');
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.repair.maxNormalizedMove<=0||cfg.repair.maxNormalizedMove>1
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:RepairMove','repair.maxNormalizedMove must be in (0,1].');
end

% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
assert_integer(cfg.experiment.numRuns,1,'cfg.experiment.numRuns');
assert(any(strcmp(cfg.strategy.selector,{'softmax','probability_matching'})), ...
    'paper:Selector','Unknown strategy selector.');
assert(any(strcmp(cfg.strategy.creditMode,{'split','accepted_net'})), ...
    'paper:Credit','Unknown credit mode.');
assert(any(strcmp(cfg.strategy.costMode,{'actual','fixed'})), ...
    'paper:Cost','Unknown cost mode.');
assert(isscalar(cfg.strategy.fixedCost)&&isfinite(cfg.strategy.fixedCost)&&cfg.strategy.fixedCost>0, ...
    'paper:Cost','fixedCost must be positive.');
end

function assert_integer(value,minimum,name)
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isscalar(value)||~isfinite(value)||value<minimum||value~=floor(value)
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('validate_config:Integer','%s must be an integer >= %g.',name,minimum);
end
end
