function bundle = evaluate_with_repair(rawZ, currentResult, problem, options, ...
    remainingFEs, maxRepairRounds)
%EVALUATE_WITH_REPAIR 评价原始候选并执行受预算限制的逐轮 CDR 修复。
%
% 返回 bundle 包含：
% rawZ/rawResult          ：搜索策略直接生成的原始候选；
% repairedZ/Results       ：每轮几何修复后的完整重评价；
% bestZ/bestResult        ：本候选束内按 Deb 规则选出的最佳结果；
% evalZ/evalResults       ：严格按实际评价顺序保存的全部位置和结果；
% nFE                     ：本候选束实际调用 problem.evaluate 的次数；
% repairInfo              ：每轮修复动作日志。
%
% 真实性说明
% -------------------------------------------------------------------------
% 1) 每次 problem.evaluate 调用都使 bundle.nFE 增加 1；
% 2) 修复器本身不评价，修复后的候选在本函数中显式重评价；
% 3) 即使修复结果变差也保留其评价记录，不能选择性删除失败修复；
% 4) 最终是否替换当前个体由 TAAS_FPO 外层 Deb 贪婪规则决定；
% 5) currentResult 当前仅为后续“接近可行域才修复”扩展保留，不改变本版逻辑。

% 若未显式提供最大修复轮数，则使用配置默认值。
if nargin < 6 || isempty(maxRepairRounds)
    % 读取配置中的修复轮数上限。
    maxRepairRounds = options.repair.maxRounds;
end

% 创建统一候选束结构。
bundle = struct();

% 初始化原始候选位置为空。
bundle.rawZ = [];

% 初始化原始候选结果为空。
bundle.rawResult = [];

% 初始化修复候选位置元胞。
bundle.repairedZ = {};

% 初始化修复候选结果元胞。
bundle.repairedResults = {};

% 初始化候选束最佳位置为空。
bundle.bestZ = [];

% 初始化候选束最佳结果为空。
bundle.bestResult = [];

% 初始化实际 FE 计数。
bundle.nFE = 0;

% 初始化每轮修复动作日志。
bundle.repairInfo = {};

% 初始化按评价顺序保存的位置元胞。
bundle.evalZ = {};

% 初始化按评价顺序保存的结果元胞。
bundle.evalResults = {};

% 没有剩余 FE 时不能执行任何完整评价。
if remainingFEs <= 0
    % 返回空候选束；正常主程序不会在此状态调用本函数。
    return;
end

% 对原始候选执行与所有算法一致的镜像边界处理。
rawZ = reflect_bounds(rawZ, problem.lb, problem.ub);

% 调用统一评价器完整评价原始候选。
rawResult = problem.evaluate(rawZ);

% 保存边界处理后的原始候选位置。
bundle.rawZ = rawZ;

% 保存原始候选完整结果。
bundle.rawResult = rawResult;

% 初始候选束最佳位置设为原始候选。
bundle.bestZ = rawZ;

% 初始候选束最佳结果设为原始结果。
bundle.bestResult = rawResult;

% 原始候选评价消耗一次 FE。
bundle.nFE = 1;

% 把原始位置保存为评价顺序中的第一项。
bundle.evalZ{1} = rawZ;

% 把原始结果保存为评价顺序中的第一项。
bundle.evalResults{1} = rawResult;

% 判断是否不需要或不能执行修复。
if ~options.repair.enabled || rawResult.isFeasible || ...
        maxRepairRounds <= 0 || ...
        ~isfield(rawResult, 'violation') || ...
        ~isfield(rawResult.violation, 'raw')
    % 直接返回只包含原始候选的候选束。
    return;
end

% 初始化当前待修复位置为原始候选。
currentZ = rawZ;

% 初始化当前待修复结果为原始结果。
repairInputResult = rawResult;

% 最多执行 maxRepairRounds 次“一轮几何修复 + 一次完整重评价”。
for repairRound = 1:maxRepairRounds
    % 若候选束已用完本次允许的 FE 或当前结果已可行，则停止修复。
    if bundle.nFE >= remainingFEs || repairInputResult.isFeasible
        % 跳出修复循环。
        break;
    end

    % 调用修复器只生成一轮几何候选，不在修复器内部评价。
    [repairCandidates, repairInformation] = ...
        problem.repair(currentZ, repairInputResult, 1);

    % 若修复器无法生成新候选，则停止修复。
    if isempty(repairCandidates)
        % 跳出修复循环。
        break;
    end

    % 取本轮修复器生成的第一行候选。
    nextZ = repairCandidates(1, :);

    % 使用统一评价器完整评价修复候选。
    nextResult = problem.evaluate(nextZ);

    % 修复候选完整重评价使 FE 增加 1。
    bundle.nFE = bundle.nFE + 1;

    % 保存本轮修复位置。
    bundle.repairedZ{end + 1} = nextZ; %#ok<AGROW>

    % 保存本轮修复完整结果，无论改善还是恶化。
    bundle.repairedResults{end + 1} = nextResult; %#ok<AGROW>

    % 保存本轮修复动作详情。
    bundle.repairInfo{end + 1} = repairInformation; %#ok<AGROW>

    % 按真实评价顺序追加本轮位置。
    bundle.evalZ{end + 1} = nextZ; %#ok<AGROW>

    % 按真实评价顺序追加本轮结果。
    bundle.evalResults{end + 1} = nextResult; %#ok<AGROW>

    % 判断本轮修复结果是否优于候选束当前最佳结果。
    if deb_better(nextResult, bundle.bestResult, ...
            options.constraint.feasibilityTolerance)
        % 更新候选束最佳位置。
        bundle.bestZ = nextZ;

        % 更新候选束最佳结果。
        bundle.bestResult = nextResult;
    end

    % 将本轮位置作为下一轮修复输入位置。
    currentZ = nextZ;

    % 将本轮完整结果作为下一轮违反类型判断依据。
    repairInputResult = nextResult;
end

% 显式引用 currentResult，说明该参数不是拼写遗漏；本版本不使用其数值。
if nargin >= 2 %#ok<INUSD>
    % 不执行任何操作，最终替换由外层主算法决定。
end
end
