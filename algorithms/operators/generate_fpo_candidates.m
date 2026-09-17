function candidates = generate_fpo_candidates(strategy, individualIndex, Zi, X, ...
    Pbest, G, pbestResults, E, H, progress, opts)
%GENERATE_FPO_CANDIDATES 根据指定 FPO 策略生成一个或两个归一化候选。
%
% 理论设计
% -------------------------------------------------------------------------
% 本函数保留原 FPO 七策略的信息来源和阶段分工，同时采用“稳定锚点形式”：
%   Z_new = anchor + signed_step。
% 这样可避免原式中把位移误当绝对位置、过度依赖坐标原点以及绝对值造成的
% 单向偏置。signVector 为逐维独立 ±1，保证在归一化空间中方向对称。
%
% 重要规则
% -------------------------------------------------------------------------
% 1) 本函数只生成候选，不做边界处理、不评价、不计 FE；
% 2) dive 和 encircle 返回两个候选，第二候选是否评价由主程序按贪婪条件决定；
% 3) 所有随机数均来自主算法已固定的随机流；
% 4) HistoricalBest、Rabbit 和精英均作为只读输入。

% 取得决策维数。
D = numel(Zi);

% 为每个维度独立生成 -1 或 +1 的对称方向。
signVector = 2 .* (rand(1, D) >= 0.5) - 1;

% 为各维度生成 [0,1] 随机幅值，供多场景及 Lévy 扰动使用。
randomVector = rand(1, D);

% 取得种群规模。
N = size(X, 1);

% 均匀随机选择一个种群个体索引。
randomIndex = randi(N);

% 读取随机个体当前位置。
Zrandom = X(randomIndex, :);

% 读取随机个体历史最优位置。
Prandom = Pbest(randomIndex, :);

% 计算当前种群平均位置。
populationMean = mean(X, 1);

% 按 Deb 可行性规则对所有个体历史最优结果从好到坏排序。
order = deb_rank(pbestResults);

% 根据配置比例确定精英个体数量，并保证至少包含一个个体。
numberOfElite = max(1, ceil(opts.algorithm.eliteFraction * N));

% 计算历史最优精英位置的平均值。
eliteMean = mean(Pbest(order(1:numberOfElite), :), 1);

% 根据策略名称执行对应位置更新。
switch lower(char(strategy))
    case 'team'
        % 生成团队成员占位策略的两个标量随机数。
        r1 = rand;
        r2 = rand;

        % 以随机个体为锚点，根据随机个体与当前个体的差异产生对称步长。
        candidate1 = Zrandom + signVector .* r1 .* ...
            abs(Zrandom - 2 .* r2 .* Zi);

        % 团队成员策略只返回一个候选。
        candidates = {candidate1};

    case 'tree'
        % 生成全局最优与种群中心差异项的随机幅值。
        rAnchor = rand;

        % 生成全空间探索扰动的随机幅值。
        rGlobal = rand;

        % 以 Rabbit 为锚点，融合 Rabbit-种群中心方向和对称全局扰动。
        candidate1 = G + signVector .* H .* ...
            (rAnchor .* (G - populationMean) + ...
            (rGlobal ^ 2) .* ones(1, D));

        % 高树策略只返回一个候选。
        candidates = {candidate1};

    case 'multi'
        % 生成 Logistic 形式的混沌系数输入。
        r = rand;

        % 计算 c=4r(1-r)，范围位于 [0,1]。
        c = 4 .* r .* (1 - r);

        % 从当前位置向随机历史最优学习，并叠加较小逐维对称扰动。
        candidate1 = Zi + c .* (Prandom - Zi) + ...
            0.1 .* signVector .* randomVector;

        % 多场景策略只返回一个候选。
        candidates = {candidate1};

    case 'highground'
        % 生成个体历史学习项的标量随机系数。
        r = rand;

        % 以 Rabbit 为锚点执行精细逼近，同时加入当前个体历史最优引导。
        candidate1 = G - E .* signVector .* abs(G - Zi) + ...
            opts.algorithm.alpha .* r .* (Pbest(individualIndex, :) - Zi);

        % 高地策略只返回一个候选。
        candidates = {candidate1};

    case 'siege'
        % 生成严格大于零的跳跃强度随机基数。
        r = max(rand, eps);

        % 按函数评价进度计算非线性跳跃强度 J。
        jumpStrength = 2 .* (1 - r ^ max(1 - progress, 0));

        % 以 Rabbit 为锚点，根据跳跃强度与当前位置差异进行围攻逼近。
        candidate1 = G - E .* signVector .* ...
            abs(jumpStrength .* G - Zi);

        % 围攻策略只返回一个候选。
        candidates = {candidate1};

    case 'dive'
        % 生成严格大于零的跳跃强度随机基数。
        r = max(rand, eps);

        % 按当前搜索进度计算自适应跳跃强度。
        jumpStrength = 2 .* (1 - r ^ max(1 - progress, 0));

        % 生成围绕 Rabbit 的基础快速俯冲位置。
        baseDive = G - E .* signVector .* ...
            abs(jumpStrength .* G - Zi);

        % 第一候选把基础俯冲位置与当前个体历史最优进行凸组合。
        candidate1 = (1 - opts.algorithm.beta) .* baseDive + ...
            opts.algorithm.beta .* Pbest(individualIndex, :);

        % 随机确定 Lévy 稳定分布指数，范围约为 [1.3,1.6]。
        betaFly = 1.3 + 0.3 .* rand;

        % 第二候选在基础俯冲位置上叠加小概率长跳跃。
        candidate2 = baseDive + 0.01 .* randomVector .* ...
            levy_flight(1, D, betaFly);

        % 快速俯冲策略按顺序返回两个候选。
        candidates = {candidate1, candidate2};

    case 'encircle'
        % 生成严格大于零的跳跃强度随机基数。
        r = max(rand, eps);

        % 按当前搜索进度计算跳跃强度。
        jumpStrength = 2 .* (1 - r ^ max(1 - progress, 0));

        % 使用移动惯性因子 H 作为种群平均信息权重。
        meanWeight = H;

        % 融合种群平均与历史精英平均，形成第一候选的群体信息中心。
        eliteCenter = meanWeight .* populationMean + ...
            (1 - meanWeight) .* eliteMean;

        % 融合种群平均与 Rabbit，形成第二候选的集体信息中心。
        mixedCenter = H .* populationMean + (1 - H) .* G;

        % 第一候选由 Rabbit、跳跃项和精英群体中心共同确定。
        candidate1 = G - E .* signVector .* ...
            abs(jumpStrength .* G - eliteCenter);

        % 随机确定第二候选 Lévy 扰动的稳定分布指数。
        betaFly = 1.3 + 0.3 .* rand;

        % 第二候选融合 Rabbit 与种群中心信息，并叠加小幅 Lévy 长跳跃。
        candidate2 = G - E .* signVector .* ...
            abs(jumpStrength .* G - mixedCenter) + ...
            0.01 .* randomVector .* levy_flight(1, D, betaFly);

        % 围猎策略按顺序返回两个候选。
        candidates = {candidate1, candidate2};

    otherwise
        % 未知策略名称属于程序配置错误，必须显式报告。
        error('generate_fpo_candidates:UnknownStrategy', ...
            'Unknown FPO strategy: %s', char(strategy));
end

% 防御性检查每个候选是否为 1×D 行向量。
for candidateIndex = 1:numel(candidates)
    % 把候选统一转换为双精度行向量。
    candidates{candidateIndex} = double(candidates{candidateIndex}(:)');

    % 检查候选维数。
    if numel(candidates{candidateIndex}) ~= D
        % 维数异常时终止，避免错误候选进入评价器。
        error('generate_fpo_candidates:CandidateDimension', ...
            'Generated candidate dimension does not match the problem dimension.');
    end
end
end
