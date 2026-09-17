function [reward, detail] = strategy_reward(oldResult, rawResult, finalResult, ...
    numberOfFEs, feasibleRate, cfg)
%STRATEGY_REWARD 基于可行性状态的单位 FE 信用；不保证与最终接受符号一致。
%
% 信用分离
% -------------------------------------------------------------------------
% old -> raw   ：搜索公式自身贡献；
% raw -> final ：约束修复贡献；
% 最终奖励     ：(R_raw + lambdaRepair*R_repair)/numberOfFEs。
%
% 这种设计防止两类偏差：
% 1) 产生第二候选或多次修复的策略因消耗更多 FE 而天然占优；
% 2) 原始候选很差、完全依靠修复器变好的策略获得全部功劳。
%
% 奖励分支与 Deb 可行性规则一致：
% - 不可行到可行：给予跃迁奖励；
% - 都不可行：只看 CV 改善；
% - 都可行：只看 F 改善；
% - 可行变不可行：给予固定负奖励。

% 根据当前种群可行率计算目标改善和违反改善的自适应权重。
[etaF, etaV] = adaptive_weights(feasibleRate, cfg);

% 评价当前个体到原始候选的状态转移，反映搜索策略本身贡献。
rawContribution = transition_reward(oldResult, rawResult, etaF, etaV, cfg);

% 判断最终候选是否为空或与原始候选完全相同。
if isempty(finalResult) || isequaln(rawResult, finalResult)
    % 没有独立修复结果时，修复贡献为零。
    repairContribution = 0;
else
    % 评价原始候选到最终候选的状态转移，反映修复带来的贡献。
    repairContribution = transition_reward(rawResult, finalResult, ...
        etaF, etaV, cfg);
end

% 将搜索贡献与折扣后的修复贡献相加，再除以实际消耗 FE。
denominator = max(numberOfFEs,1);
if isfield(cfg.strategy,'costMode') && strcmp(cfg.strategy.costMode,'fixed')
    denominator = cfg.strategy.fixedCost;
    assert(isfinite(denominator)&&denominator>0,'paper:Cost','fixedCost must be positive.');
end
numerator = rawContribution + cfg.strategy.lambdaRepair * repairContribution;
if isfield(cfg.strategy,'creditMode') && strcmp(cfg.strategy.creditMode,'accepted_net')
    numerator = 0;
    if deb_better(finalResult,oldResult,cfg.constraint.feasibilityTolerance)
        numerator = transition_reward(oldResult,finalResult,etaF,etaV,cfg);
    end
end
reward = numerator / denominator;

% 检查奖励是否为有限数。
if ~isfinite(reward)
    % 非有限奖励用负上限替代，避免污染 softmax 策略统计。
    reward = -cfg.strategy.rewardCap;
else
    % 将奖励截断在固定区间，防止单次极端改善使概率过早塌缩。
    reward = clip_value(reward, -cfg.strategy.rewardCap, ...
        cfg.strategy.rewardCap);
end

% 创建奖励分解结构，供日志和机制分析使用。
detail = struct();

% 保存搜索公式直接贡献。
detail.raw = rawContribution;

% 保存修复器独立贡献。
detail.repair = repairContribution;

% 保存本次使用的目标改善权重。
detail.etaF = etaF;

% 保存本次使用的违反改善权重。
detail.etaV = etaV;

% 保存本次策略实际消耗的函数评价次数。
detail.nFE = numberOfFEs;
detail.denominator = denominator;
detail.numerator = numerator;
end

function [etaF, etaV] = adaptive_weights(feasibleRate, cfg)
%ADAPTIVE_WEIGHTS 根据当前可行率连续调整质量与可行性奖励权重。

% 读取低可行率阈值。
lowThreshold = cfg.strategy.feasibleLowThreshold;

% 读取高可行率阈值。
highThreshold = cfg.strategy.feasibleHighThreshold;

% 在低可行率区间，优先奖励约束违反改善。
if feasibleRate <= lowThreshold
    % 插值系数取 0。
    interpolation = 0;
elseif feasibleRate >= highThreshold
    % 在高可行率区间，优先奖励目标质量改善。
    interpolation = 1;
else
    % 在两个阈值之间线性插值。
    interpolation = (feasibleRate - lowThreshold) / ...
        (highThreshold - lowThreshold);
end

% 对目标改善权重进行线性插值。
etaF = (1 - interpolation) * cfg.strategy.lowFeasibleEtaF + ...
    interpolation * cfg.strategy.highFeasibleEtaF;

% 对违反改善权重进行线性插值。
etaV = (1 - interpolation) * cfg.strategy.lowFeasibleEtaV + ...
    interpolation * cfg.strategy.highFeasibleEtaV;
end

function transitionValue = transition_reward(a, b, etaF, etaV, cfg)
%TRANSITION_REWARD 按可行性状态组合计算一次状态转移奖励。

% 情况一：旧解不可行而新解可行。
if ~a.isFeasible && b.isFeasible
    % 计算 CV 的相对下降比例。
    relativeCVImprovement = max(0, (a.CV - b.CV) / (abs(a.CV) + eps));

    % 给予固定可行跃迁奖励，并叠加违反改善奖励。
    transitionValue = cfg.strategy.crossReward + etaV * relativeCVImprovement;

% 情况二：新旧解都不可行。
elseif ~a.isFeasible && ~b.isFeasible
    % 计算 CV 的相对下降比例。
    relativeCVImprovement = max(0, (a.CV - b.CV) / (abs(a.CV) + eps));

    % 只奖励约束违反改善，忽略可能很短但碰撞的目标值。
    transitionValue = etaV * relativeCVImprovement;

% 情况三：新旧解都可行。
elseif a.isFeasible && b.isFeasible
    % 计算综合目标 F 的相对下降比例。
    relativeObjectiveImprovement = max(0, ...
        (a.F - b.F) / (abs(a.F) + eps));

    % 只奖励可行域内的目标质量改善。
    transitionValue = etaF * relativeObjectiveImprovement;

% 情况四：旧解可行而新解不可行。
else
    % 对丢失可行性给予固定负奖励。
    transitionValue = -cfg.strategy.lossPenalty;
end
end
