function [bestCost, bestZ, convergence, output] = TAAS_FPO(problem, userOptions)
%TAAS_FPO 地形感知自适应策略游隼优化算法完整主程序。
%
% 调用形式
% -------------------------------------------------------------------------
% [bestCost,bestZ,convergence,output] = TAAS_FPO(problem,userOptions)
%
% problem 必需字段
% -------------------------------------------------------------------------
% dim、lb、ub、evaluate、repair、initializer、cfg。
%
% 算法结构
% -------------------------------------------------------------------------
% 1) TAI 地形感知混合初始化；
% 2) 逃逸能量 |E| 保留原 FPO 探索/开发阶段门控；
% 3) ASA 在阶段内部根据单位 FE 奖励学习七策略概率；
% 4) CDR 对不同约束类型执行有限几何修复；
% 5) Deb 可行性规则统一更新当前位置、HistoricalBest 和 Rabbit；
% 6) 停滞且低多样性时重置最差部分个体。
%
% 实验真实性与公平性约束
% -------------------------------------------------------------------------
% 1) 每次 problem.evaluate 调用均显式计为 1 FE；
% 2) 第二候选和每轮修复后的重评价均计入实际 FE；
% 3) 搜索进度使用 FEs/MaxFEs，避免不同候选数量形成不同隐性时间尺度；
% 4) 所有可行性和最优更新均使用同一 Deb 规则；
% 5) 路径专用初始化、修复和策略学习均可独立关闭以支持消融；
% 6) 主程序不修改 problem.env、原始 DEM、障碍轨迹或历史结果文件；
% 7) 初始种群至少保证每个个体完成一次原始评价，初始化修复不得挤占剩余
%    未评价个体所需的最低 FE。

%% 一、输入检查与配置冻结

% 若调用方未提供覆盖配置，则使用空结构。
if nargin < 2
    % 空结构表示完全采用 problem.cfg。
    userOptions = struct();
end

% 检查问题结构是否包含基础配置。
if ~isfield(problem, 'cfg')
    % 没有配置无法保证评价器和算法参数一致。
    error('TAAS_FPO:ProblemConfig', 'problem.cfg is required.');
end

% 在问题冻结配置上递归覆盖用户显式提供的字段。
options = merge_structs(problem.cfg, userOptions);

% 检查合并后的配置是否合法。
validate_config(options);

% 读取种群规模。
N = options.algorithm.N;

% 读取最大函数评价预算。
MaxFEs = options.algorithm.MaxFEs;

% 读取决策维数。
D = problem.dim;

% 至少需要 N 次 FE 才能完整评价初始种群。
if MaxFEs < N
    % 预算不足时终止，避免部分个体没有评价结果。
    error('TAAS_FPO:BudgetTooSmall', ...
        'MaxFEs must be at least equal to the population size N.');
end

% 检查上下界长度是否与问题维数一致。
if numel(problem.lb) ~= D || numel(problem.ub) ~= D
    % 边界维数错误会导致位置更新和反射失真。
    error('TAAS_FPO:Bounds', ...
        'problem.lb and problem.ub must match problem.dim.');
end

% 使用配置中的固定算法种子重置 MATLAB 随机流。
rng(options.algorithm.seed, 'twister');

% 启动算法总运行时间计时器。
startClock = tic;

%% 二、初始化种群和全部状态存储

% 根据配置决定使用地形感知初始化还是统一随机初始化。
if options.initialization.enabled && isfield(problem, 'initializer')
    % 调用问题提供的初始化器生成 N 个归一化个体及来源元数据。
    [X, initializationMeta] = problem.initializer(N, false);
else
    % 生成 N×D 的 [0,1] 均匀随机矩阵。
    unitRandom = rand(N, D);

    % 将单位随机矩阵显式映射到 problem.lb 与 problem.ub。
    X = bsxfun(@plus, problem.lb, ...
        bsxfun(@times, unitRandom, problem.ub - problem.lb));

    % 创建随机初始化来源元数据。
    initializationMeta = struct();

    % 给所有个体标记随机来源。
    initializationMeta.source = repmat("random", N, 1);

    % 随机初始化没有 A* 种子路径。
    initializationMeta.seedPaths = {};

    % 当前不是停滞重启初始化。
    initializationMeta.isRestart = false;
end

% 对全部初始位置执行统一镜像边界处理。
X = reflect_bounds(X, problem.lb, problem.ub);

% 为每个个体预分配当前完整评价结果元胞。
currentResults = cell(N, 1);

% 将个体历史最优位置初始设为其初始位置。
personalBest = X;

% 为每个个体预分配历史最优完整评价结果。
personalBestResults = cell(N, 1);

% 初始化全局最优 Rabbit 位置为空。
globalBest = [];

% 初始化 Rabbit 完整评价结果为空。
globalBestResult = [];

% 初始化实际函数评价次数。
FEs = 0;

% 初始化首次发现可行解的 FE 索引为 NaN。
firstFeasibleFE = NaN;

% 初始化最近一次 Rabbit 改进发生的 FE。
lastImprovementFE = 0;

% 初始化最近一次停滞重启 FE 为负无穷。
lastRestartFE = -inf;

% 为每个个体初始化探索门控覆盖剩余次数。
overrideCount = zeros(N, 1);

% 初始化三个阶段的七策略统计。
strategyStats = init_strategy_stats(options);
strategyEvents = cell(MaxFEs,1);
strategyEventCount = 0;

% 初始化修复器统计结构。
repairStats = initialize_repair_stats();

% 初始化 FE 横轴收敛日志。
logData = initialize_log();

% 初始化停滞重启事件结构数组。
stagnationEvents = struct('FE', {}, 'indices', {}, ...
    'diversityBefore', {}, 'diversityAfter', {}, ...
    'bestBefore', {}, 'bestAfter', {});

%% 三、评价初始种群，所有评价与初始化修复均显式计 FE

% 逐个评价初始种群。
for individualIndex = 1:N
    % 计算当前剩余 FE 总预算。
    remainingTotalBudget = MaxFEs - FEs;

    % 计算当前个体之后仍未完成原始评价的个体数量。
    remainingUnevaluatedIndividuals = N - individualIndex;

    % 为当前个体保留至少一次原始评价，同时给后续每个个体保留一 FE。
    currentBundleBudget = remainingTotalBudget - remainingUnevaluatedIndividuals;

    % 防御性检查当前个体至少应有一个评价预算。
    if currentBundleBudget < 1
        % 该情况说明 FE 记账或输入预算存在逻辑错误。
        error('TAAS_FPO:InitializationBudget', ...
            'Insufficient protected budget for complete population initialization.');
    end

    % 复制配置，避免局部关闭修复修改全局 options。
    localOptions = options;

    % 只有同时开启修复和初始化修复时才允许初始候选修复。
    localOptions.repair.enabled = options.repair.enabled && ...
        options.repair.applyDuringInitialization;

    % 在受保护预算内评价原始个体并执行有限初始化修复。
    bundle = evaluate_with_repair(X(individualIndex, :), [], problem, ...
        localOptions, currentBundleBudget, options.repair.maxInitRounds);

    % 按实际评价顺序登记 FE、首次可行和 Rabbit 更新。
    [FEs, globalBest, globalBestResult, firstFeasibleFE, ...
        lastImprovementFE] = register_bundle(bundle, FEs, globalBest, ...
        globalBestResult, firstFeasibleFE, lastImprovementFE, options);

    % 累加当前候选束的修复调用和效果统计。
    repairStats = accumulate_repair_stats(repairStats, bundle);

    % 把当前个体位置替换为本候选束按 Deb 规则选出的最佳位置。
    X(individualIndex, :) = bundle.bestZ;

    % 保存该个体当前结果。
    currentResults{individualIndex} = bundle.bestResult;

    % 初始历史最优位置等于初始化完成后的当前位置。
    personalBest(individualIndex, :) = X(individualIndex, :);

    % 初始历史最优结果等于初始化完成后的当前结果。
    personalBestResults{individualIndex} = currentResults{individualIndex};

    % 若达到日志间隔，则记录一次搜索状态。
    [logData, ~] = append_log_if_due(logData, FEs, globalBestResult, ...
        X, currentResults, strategyStats, options, false);
end

% 检查所有个体是否都已有完整结果。
if any(cellfun(@isempty, currentResults))
    % 不完整初始种群不能进入主循环。
    error('TAAS_FPO:IncompleteInitialization', ...
        'At least one initial individual has no evaluation result.');
end

%% 四、主搜索循环

% 初始化外层等价迭代计数，仅用于诊断，不作为停止条件。
iteration = 0;

% 只要还有 FE 预算就继续搜索。
while FEs < MaxFEs
    % 增加一轮外层种群扫描计数。
    iteration = iteration + 1;

    % 按当前种群顺序逐个更新个体。
    for individualIndex = 1:N
        % 若 FE 已用尽，则提前结束当前种群扫描。
        if FEs >= MaxFEs
            % 跳出个体循环。
            break;
        end

        % 保存更新前的个体位置。
        oldZ = X(individualIndex, :);

        % 保存更新前的个体完整结果。
        oldResult = currentResults{individualIndex};

        % 用实际 FE 比例计算归一化搜索进度。
        progress = min(max(FEs / MaxFEs, 0), 1);

        % 计算原 FPO 的非线性渐进能量衰减幅值。
        energyAmplitude = 2 * (1 - progress ^ 2);

        % 生成位于 [-1,1] 的个体随机初始能量。
        initialEnergy = 2 * (rand - 0.5);

        % 得到当前个体逃逸能量 E。
        escapingEnergy = energyAmplitude * initialEnergy;

        % 计算随搜索进度从 0.9 下降到 0.1 的移动惯性因子 H。
        movementInertia = 0.9 - 0.8 * progress;

        % 确定当前个体使用的策略阶段。
        if overrideCount(individualIndex) > 0
            % 停滞重置后的有限次更新强制进入探索阶段。
            stage = 'exploration';

            % 消耗一次探索门控覆盖次数。
            overrideCount(individualIndex) = ...
                overrideCount(individualIndex) - 1;
        elseif abs(escapingEnergy) >= 1
            % 高逃逸能量对应全局探索阶段。
            stage = 'exploration';
        elseif abs(escapingEnergy) >= 0.5
            % 中等逃逸能量对应围攻/快速俯冲开发阶段。
            stage = 'development_high';
        else
            % 低逃逸能量对应高地/围猎精细开发阶段。
            stage = 'development_low';
        end

        % 在当前阶段内根据预热规则或学习概率选择具体策略。
        [strategyIndex, strategyName, strategyStats, selectedProbabilities] = ...
            select_strategy(strategyStats, stage, options);

        % 根据七策略稳定公式生成一个或两个原始候选。
        candidateList = generate_fpo_candidates(strategyName, ...
            individualIndex, oldZ, X, personalBest, globalBest, ...
            personalBestResults, escapingEnergy, movementInertia, ...
            progress, options);

        % 计算当前剩余 FE。
        remainingBudget = MaxFEs - FEs;

        % 评价第一候选及其有限修复链。
        firstBundle = evaluate_with_repair(candidateList{1}, oldResult, ...
            problem, options, remainingBudget, options.repair.maxRounds);

        % 登记第一候选束中的所有实际评价。
        [FEs, globalBest, globalBestResult, firstFeasibleFE, ...
            lastImprovementFE] = register_bundle(firstBundle, FEs, ...
            globalBest, globalBestResult, firstFeasibleFE, ...
            lastImprovementFE, options);

        % 累加第一候选束修复统计。
        repairStats = accumulate_repair_stats(repairStats, firstBundle);

        % 暂时把第一候选束设为本策略最佳候选束。
        selectedBundle = firstBundle;

        % 初始化本次策略实际消耗 FE 为第一候选束消耗。
        totalStrategyFEs = firstBundle.nFE;

        % 只有存在第二候选、仍有预算且第一候选束未改善当前个体时才评价第二候选。
        if numel(candidateList) >= 2 && FEs < MaxFEs && ...
                ~deb_better(firstBundle.bestResult, oldResult, ...
                options.constraint.feasibilityTolerance)
            % 重新计算剩余 FE。
            remainingBudget = MaxFEs - FEs;

            % 评价第二候选及其有限修复链。
            secondBundle = evaluate_with_repair(candidateList{2}, ...
                oldResult, problem, options, remainingBudget, ...
                options.repair.maxRounds);

            % 登记第二候选束的实际评价。
            [FEs, globalBest, globalBestResult, firstFeasibleFE, ...
                lastImprovementFE] = register_bundle(secondBundle, FEs, ...
                globalBest, globalBestResult, firstFeasibleFE, ...
                lastImprovementFE, options);

            % 累加第二候选束修复统计。
            repairStats = accumulate_repair_stats(repairStats, secondBundle);

            % 将第二候选束消耗加入策略总 FE 成本。
            totalStrategyFEs = totalStrategyFEs + secondBundle.nFE;

            % 若第二候选束按 Deb 规则优于第一候选束，则选用第二束。
            if deb_better(secondBundle.bestResult, ...
                    selectedBundle.bestResult, ...
                    options.constraint.feasibilityTolerance)
                % 更新本策略最终候选束。
                selectedBundle = secondBundle;
            end
        end

        % 判断本策略最佳候选是否优于当前个体。
        accepted = deb_better(selectedBundle.bestResult, oldResult, ...
            options.constraint.feasibilityTolerance);

        % 只有候选更优时才贪婪替换当前位置。
        if accepted
            % 更新当前个体位置。
            X(individualIndex, :) = selectedBundle.bestZ;

            % 更新当前个体完整结果。
            currentResults{individualIndex} = selectedBundle.bestResult;
        end

        % 判断当前位置是否优于该个体历史最优。
        if deb_better(currentResults{individualIndex}, ...
                personalBestResults{individualIndex}, ...
                options.constraint.feasibilityTolerance)
            % 更新个体历史最优位置。
            personalBest(individualIndex, :) = X(individualIndex, :);

            % 更新个体历史最优结果。
            personalBestResults{individualIndex} = ...
                currentResults{individualIndex};
        end

        % 计算当前种群中可行个体比例。
        feasibleRate = mean(cellfun(@(r) r.isFeasible, currentResults));

        % 计算分离搜索与修复信用、按实际 FE 归一化的策略奖励。
        [reward, rewardDetail] = strategy_reward(oldResult, ...
            selectedBundle.rawResult, selectedBundle.bestResult, ...
            totalStrategyFEs, feasibleRate, options);

        if isfield(options.strategy,'recordEvents') && options.strategy.recordEvents
            strategyEventCount=strategyEventCount+1;
            strategyEvents{strategyEventCount}=struct('FE',FEs,'stage',stage, ...
                'strategy',strategyName,'strategyIndex',strategyIndex, ...
                'actualFEs',totalStrategyFEs,'rawCredit',rewardDetail.raw, ...
                'repairCredit',rewardDetail.repair,'reward',reward, ...
                'denominator',rewardDetail.denominator,'accepted',accepted, ...
                'oldF',oldResult.F,'oldCV',oldResult.CV, ...
                'rawF',selectedBundle.rawResult.F,'rawCV',selectedBundle.rawResult.CV, ...
                'finalF',selectedBundle.bestResult.F,'finalCV',selectedBundle.bestResult.CV, ...
                'probabilities',selectedProbabilities,'feasibleRate',feasibleRate);
        end

        % 判断本候选束是否完成不可行到可行跃迁。
        crossedToFeasible = ~oldResult.isFeasible && ...
            selectedBundle.bestResult.isFeasible;

        % 更新当前阶段对应策略的调用、成功、奖励窗口和 Q 值。
        strategyStats = update_strategy_stats(strategyStats, stage, ...
            strategyIndex, reward, accepted, totalStrategyFEs, ...
            crossedToFeasible, options);

        % 按 FE 日志间隔记录当前搜索状态。
        [logData, ~] = append_log_if_due(logData, FEs, ...
            globalBestResult, X, currentResults, strategyStats, ...
            options, false);

        % 开发阶段可选地执行边界、概率和 FE 不变量检查。
        if options.algorithm.assertInvariants
            % 任何不变量失败都应终止实验，禁止静默修补结果。
            assert_algorithm_invariants(X, currentResults, ...
                strategyStats, FEs, MaxFEs, options);
        end
    end

    %% 五、停滞检测与最差个体重置

    % 只有启用停滞恢复且仍有 FE 预算时才检查。
    if options.stagnation.enabled && FEs < MaxFEs
        % 计算当前归一化种群平均 L1 多样性。
        diversity = population_diversity(X);

        % 将配置的等价种群窗口换算为 FE 间隔。
        requiredGap = ...
            options.stagnation.windowEquivalentPopulations * N;

        % 判断距离最近 Rabbit 改进是否已超过停滞窗口。
        stagnated = (FEs - lastImprovementFE) >= requiredGap;

        % 判断距离上次重启是否已超过冷却间隔。
        cooled = (FEs - lastRestartFE) >= options.stagnation.cooldownFEs;

        % 只有同时停滞、低多样性且完成冷却才触发重启。
        if stagnated && diversity < options.stagnation.diversityMin && cooled
            % 保存重启前 Rabbit 结果用于事件日志。
            bestBeforeRestart = globalBestResult;

            % 按配置比例计算重置个体数量，并保证至少一个。
            numberToRestart = max(1, ...
                round(options.stagnation.restartFraction * N));

            % 按 Deb 规则从好到坏排列当前个体。
            ranking = deb_rank(currentResults);

            % 选取排名末尾的最差若干个体进行重置。
            restartIndices = ranking(end - numberToRestart + 1:end);

            % 根据初始化配置生成重启位置。
            if options.initialization.enabled && isfield(problem, 'initializer')
                % 使用重启模式的地形感知初始化器。
                [restartPopulation, ~] = ...
                    problem.initializer(numberToRestart, true);
            else
                % 生成单位随机矩阵。
                randomRestart = rand(numberToRestart, D);

                % 显式映射到问题边界。
                restartPopulation = bsxfun(@plus, problem.lb, ...
                    bsxfun(@times, randomRestart, ...
                    problem.ub - problem.lb));
            end

            % 对全部重启位置执行统一镜像反射。
            restartPopulation = reflect_bounds(restartPopulation, ...
                problem.lb, problem.ub);

            % 逐个评价重启个体，直到数量完成或 FE 用尽。
            for restartCounter = 1:numberToRestart
                % 若没有剩余 FE 则停止重启评价。
                if FEs >= MaxFEs
                    % 跳出重启个体循环。
                    break;
                end

                % 读取被替换的原种群索引。
                populationIndex = restartIndices(restartCounter);

                % 计算当前剩余 FE。
                remainingBudget = MaxFEs - FEs;

                % 复制配置以局部控制重启初始化修复。
                localOptions = options;

                % 只有配置允许时才对重启个体执行初始化修复。
                localOptions.repair.enabled = options.repair.enabled && ...
                    options.repair.applyDuringInitialization;

                % 评价重启位置及有限初始化修复。
                bundle = evaluate_with_repair( ...
                    restartPopulation(restartCounter, :), [], problem, ...
                    localOptions, remainingBudget, ...
                    options.repair.maxInitRounds);

                % 登记重启候选束中的所有评价。
                [FEs, globalBest, globalBestResult, firstFeasibleFE, ...
                    lastImprovementFE] = register_bundle(bundle, FEs, ...
                    globalBest, globalBestResult, firstFeasibleFE, ...
                    lastImprovementFE, options);

                % 累加重启候选束修复统计。
                repairStats = accumulate_repair_stats(repairStats, bundle);

                % 用新位置替换对应最差个体。
                X(populationIndex, :) = bundle.bestZ;

                % 更新该个体当前结果。
                currentResults{populationIndex} = bundle.bestResult;

                % 重置该个体历史最优位置，避免保留旧通道记忆。
                personalBest(populationIndex, :) = X(populationIndex, :);

                % 重置该个体历史最优结果。
                personalBestResults{populationIndex} = ...
                    currentResults{populationIndex};

                % 给该个体设置有限次探索门控覆盖。
                overrideCount(populationIndex) = ...
                    options.stagnation.overrideUpdates;
            end

            % 创建本次停滞重启事件记录。
            event = struct();

            % 保存重启完成时的实际 FE。
            event.FE = FEs;

            % 保存计划重启的个体索引。
            event.indices = restartIndices(:)';

            % 保存重启前种群多样性。
            event.diversityBefore = diversity;

            % 保存重启后种群多样性。
            event.diversityAfter = population_diversity(X);

            % 保存重启前 Rabbit 结果。
            event.bestBefore = bestBeforeRestart;

            % 保存重启后 Rabbit 结果。
            event.bestAfter = globalBestResult;

            % 把事件追加到停滞事件数组。
            stagnationEvents(end + 1) = event; %#ok<AGROW>

            % 更新最近一次重启 FE。
            lastRestartFE = FEs;

            % 从重启完成处重新开始停滞窗口，防止连续触发。
            lastImprovementFE = max(lastImprovementFE, FEs);

            % 强制记录一次带重启标记的日志。
            [logData, ~] = append_log_if_due(logData, FEs, ...
                globalBestResult, X, currentResults, strategyStats, ...
                options, true);
        end
    end
end

%% 六、整理最终输出

% 强制记录最终 FE 状态；若同一 FE 已存在则更新该行而不重复追加。
[logData, ~] = append_log_if_due(logData, FEs, globalBestResult, ...
    X, currentResults, strategyStats, options, true);

% 返回最终 Rabbit 的综合目标值。
bestCost = globalBestResult.F;

% 返回最终 Rabbit 的归一化位置。
bestZ = globalBest;

% 构造以实际 FE 为横轴的收敛结构。
convergence = struct('FE', logData.FE, 'bestF', logData.bestF, ...
    'bestCV', logData.bestCV, 'feasibleRate', logData.feasibleRate, ...
    'diversity', logData.diversity);

% 创建完整输出结构。
output = struct();

% 保存最终 Rabbit 完整评价结果。
output.bestResult = globalBestResult;

% 保存最终 Rabbit 位置。
output.bestZ = globalBest;

% 保存最终种群位置。
output.finalPopulation = X;

% 保存最终种群每个个体完整结果。
output.finalResults = currentResults;

% 保存最终个体历史最优位置。
output.personalBest = personalBest;

% 保存最终个体历史最优结果。
output.personalBestResults = personalBestResults;

% 保存七策略全部统计。
output.strategyStats = strategyStats;
output.strategyEvents = strategyEvents(1:strategyEventCount);

% 保存约束修复统计。
output.repairStats = repairStats;

% 保存完整 FE 日志。
output.log = logData;

% 保存首次找到可行解的 FE；未找到时为 NaN。
output.firstFeasibleFE = firstFeasibleFE;

% 保存实际消耗的函数评价次数。
output.actualFEs = FEs;

% 保存外层种群扫描次数，仅用于诊断。
output.iterations = iteration;

% 保存算法实际墙钟运行时间。
output.runtime = toc(startClock);

% 保存初始化来源和种子路径元数据。
output.initializationMeta = initializationMeta;

% 保存所有停滞重启事件。
output.stagnationEvents = stagnationEvents;

% 保存本次运行实际使用的完整配置。
output.options = options;

% 创建复现信息结构。
output.reproducibility = struct();

% 保存算法随机种子。
output.reproducibility.seed = options.algorithm.seed;

% 保存 MATLAB 版本。
output.reproducibility.matlabVersion = version;

% 保存计算机平台标识。
output.reproducibility.computer = computer;

% 保存完成时间；该字段不参与数值复现比较。
output.reproducibility.timestamp = datestr(now,30);

% 当启用详细输出时打印最终摘要。
if options.algorithm.verbose
    % 输出 FE、可行性、目标、违反度和运行时间。
    fprintf(['\nTAAS-FPO finished: FEs=%d, feasible=%d, ', ...
        'F=%.8g, CV=%.8g, runtime=%.2fs\n'], ...
        FEs, globalBestResult.isFeasible, globalBestResult.F, ...
        globalBestResult.CV, output.runtime);
end
end

function [FEs, globalBest, globalBestResult, firstFeasibleFE, ...
    lastImprovementFE] = register_bundle(bundle, FEs, globalBest, ...
    globalBestResult, firstFeasibleFE, lastImprovementFE, options)
%REGISTER_BUNDLE 按实际评价顺序登记候选束中的每一次完整评价。

% 保存候选束开始前的 FE。
startFE = FEs;

% 逐个处理原始候选和各轮修复候选的评价结果。
for evaluationIndex = 1:numel(bundle.evalResults)
    % 计算当前评价在全局运行中的 FE 索引。
    currentFE = startFE + evaluationIndex;

    % 读取当前完整评价结果。
    currentResult = bundle.evalResults{evaluationIndex};

    % 读取与当前结果对应的归一化位置。
    currentZ = bundle.evalZ{evaluationIndex};

    % 若此前未找到可行解且当前结果可行，则记录首次可行 FE。
    if isnan(firstFeasibleFE) && currentResult.isFeasible
        % 保存当前 FE 索引。
        firstFeasibleFE = currentFE;
    end

    % 若 Rabbit 为空或当前结果按 Deb 规则更优，则更新全局最优。
    if isempty(globalBestResult) || deb_better(currentResult, ...
            globalBestResult, options.constraint.feasibilityTolerance)
        % 更新 Rabbit 完整结果。
        globalBestResult = currentResult;

        % 更新 Rabbit 位置。
        globalBest = currentZ;

        % 保存最近一次 Rabbit 改进 FE。
        lastImprovementFE = currentFE;
    end
end

% 按候选束显式记录的评价次数更新总 FE。
FEs = startFE + bundle.nFE;
end

function stats = initialize_repair_stats()
%INITIALIZE_REPAIR_STATS 创建修复器累计统计结构。

% 创建统计结构并初始化标量字段。
stats = struct('calls', 0, 'evaluations', 0, ...
    'successfulBundles', 0, 'byType', struct(), ...
    'rawToBestCVImprovement', []);
end

function stats = accumulate_repair_stats(stats, bundle)
%ACCUMULATE_REPAIR_STATS 累加一个候选束中的修复调用和效果。

% 没有修复评价时无需更新统计。
if isempty(bundle.repairedResults)
    % 直接返回原统计。
    return;
end

% 增加发生过修复的候选束数量。
stats.calls = stats.calls + 1;

% 累加修复后完整重评价次数。
stats.evaluations = stats.evaluations + numel(bundle.repairedResults);

% 若原始候选不可行而候选束最佳结果可行，则增加修复成功束计数。
stats.successfulBundles = stats.successfulBundles + ...
    double(bundle.bestResult.isFeasible && ~bundle.rawResult.isFeasible);

% 记录原始候选到候选束最佳结果的 CV 改善。
stats.rawToBestCVImprovement(end + 1) = ...
    bundle.rawResult.CV - bundle.bestResult.CV; %#ok<AGROW>

% 逐轮读取修复动作类型。
for repairIndex = 1:numel(bundle.repairInfo)
    % 读取当前轮修复信息。
    repairInformation = bundle.repairInfo{repairIndex};

    % 逐个处理当前轮记录的动作。
    for actionIndex = 1:numel(repairInformation.actions)
        % 读取动作类型字符串。
        actionType = repairInformation.actions{actionIndex}.type;

        % 跳过空类型和无动作标志。
        if isempty(actionType) || strcmp(actionType, 'none')
            % 继续处理下一个动作。
            continue;
        end

        % 将类型转换为合法 MATLAB 结构字段名。
        fieldKey = matlab.lang.makeValidName(actionType);

        % 首次出现该类型时初始化计数。
        if ~isfield(stats.byType, fieldKey)
            % 初始化为零。
            stats.byType.(fieldKey) = 0;
        end

        % 增加当前修复类型调用次数。
        stats.byType.(fieldKey) = stats.byType.(fieldKey) + 1;
    end
end
end

function logData = initialize_log()
%INITIALIZE_LOG 创建以实际 FE 为横轴的搜索日志结构。

% 初始化全部日志向量和七策略矩阵。
logData = struct('FE', [], 'bestF', [], 'bestCV', [], ...
    'bestFeasible', [], 'feasibleRate', [], 'diversity', [], ...
    'strategyProb', zeros(0, 7), 'strategyQ', zeros(0, 7), ...
    'restartMarker', []);
end

function [logData, added] = append_log_if_due(logData, FEs, ...
    globalBestResult, X, results, strategyStats, options, force)
%APPEND_LOG_IF_DUE 按 FE 间隔记录搜索状态，并避免同一 FE 重复行。

% 默认本次没有新增日志。
added = false;

% Rabbit 尚未建立时没有可记录内容。
if isempty(globalBestResult)
    % 直接返回。
    return;
end

% 判断当前 FE 是否已经存在于最后一条日志。
sameFEAsLast = ~isempty(logData.FE) && logData.FE(end) == FEs;

% 若日志为空，则当前状态必然需要记录。
if isempty(logData.FE)
    % 设置到期标志。
    due = true;
else
    % 计算距离上一条日志的 FE 间隔是否达到阈值。
    due = (FEs - logData.FE(end)) >= options.algorithm.logEveryFE;
end

% 非强制且未达到日志间隔时不记录。
if ~(due || force)
    % 返回原日志。
    return;
end

% 若同一 FE 已存在，则更新最后一行而不是追加重复横轴点。
if sameFEAsLast
    % 使用最后一行索引。
    rowIndex = numel(logData.FE);
else
    % 新日志行索引为当前长度加一。
    rowIndex = numel(logData.FE) + 1;

    % 保存当前 FE 横轴值。
    logData.FE(rowIndex, 1) = FEs;
end

% 保存当前 Rabbit 综合目标。
logData.bestF(rowIndex, 1) = globalBestResult.F;

% 保存当前 Rabbit 总违反度。
logData.bestCV(rowIndex, 1) = globalBestResult.CV;

% 保存当前 Rabbit 可行性。
logData.bestFeasible(rowIndex, 1) = globalBestResult.isFeasible;

% 识别已有完整结果的个体。
valid = ~cellfun(@isempty, results);

% 若存在有效个体，则计算可行率。
if any(valid)
    % 对有效结果的可行标志取平均。
    logData.feasibleRate(rowIndex, 1) = ...
        mean(cellfun(@(r) r.isFeasible, results(valid)));
else
    % 没有有效个体时可行率记为零。
    logData.feasibleRate(rowIndex, 1) = 0;
end

% 保存当前种群多样性。
logData.diversity(rowIndex, 1) = population_diversity(X);

% 保存固定顺序的七策略概率。
logData.strategyProb(rowIndex, :) = ...
    all_strategy_probabilities(strategyStats, options);

% 保存固定顺序的七策略 Q 值。
logData.strategyQ(rowIndex, :) = [strategyStats.exp.Q, ...
    strategyStats.high.Q, strategyStats.low.Q];

% 保存当前日志是否由强制事件触发；同 FE 更新时保留已有重启标志。
if sameFEAsLast
    % 只要原标志或当前 force 任一为真，最终标志即为真。
    logData.restartMarker(rowIndex, 1) = max( ...
        logData.restartMarker(rowIndex, 1), double(force));
else
    % 新行直接记录 force 标志。
    logData.restartMarker(rowIndex, 1) = double(force);
end

% 标记本次已新增或更新日志。
added = true;
end

function assert_algorithm_invariants(X, results, strategyStats, FEs, ...
    MaxFEs, options)
%ASSERT_ALGORITHM_INVARIANTS 检查边界、FE、结果完整性和策略概率。

% 检查种群是否包含非有限数或越过归一化边界。
if any(~isfinite(X(:))) || any(X(:) < -1e-12) || ...
        any(X(:) > 1 + 1e-12)
    % 边界不变量失败时终止算法。
    error('TAAS_FPO:InvariantBounds', ...
        'Population contains nonfinite or out-of-bound values.');
end

% 检查实际 FE 是否超过最大预算。
if FEs > MaxFEs
    % FE 超预算说明候选或修复记账存在错误。
    error('TAAS_FPO:InvariantFE', 'FEs exceeded MaxFEs.');
end

% 检查每个种群个体是否都有完整结果。
if any(cellfun(@isempty, results))
    % 结果缺失时终止算法。
    error('TAAS_FPO:InvariantResult', ...
        'At least one individual has no evaluation result.');
end

% 固定三个策略统计分组键。
groupKeys = {'exp', 'high', 'low'};

% 逐阶段检查策略概率。
for groupIndex = 1:numel(groupKeys)
    % 计算当前阶段策略概率。
    probabilities = strategy_probabilities( ...
        strategyStats.(groupKeys{groupIndex}), options);

    % 检查概率非负且总和近似为 1。
    if any(probabilities < -1e-12) || abs(sum(probabilities) - 1) > 1e-10
        % 概率不变量失败时终止算法。
        error('TAAS_FPO:InvariantProbability', ...
            'Invalid strategy probability vector.');
    end
end
end
