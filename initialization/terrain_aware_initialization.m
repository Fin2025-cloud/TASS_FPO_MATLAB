function [X, meta] = terrain_aware_initialization(problem, N, isRestart)
%TERRAIN_AWARE_INITIALIZATION 生成 TAAS-FPO 的地形感知混合初始种群。
%
% 种群组成
% -------------------------------------------------------------------------
% 1) 多通道种子组：由粗网格 A* 产生若干不同山谷通道；
% 2) Tent 邻域组：围绕不同通道种子进行逐维对称扰动；
% 3) 构造式全局组：沿任务进度生成具有地形净空的宽范围样本。
%
% 真实性说明
% -------------------------------------------------------------------------
% 本函数只生成归一化位置，不调用 problem.evaluate，也不声称样本已经可行。
% 初始种群的所有完整评价及初始化修复均由 TAAS_FPO 主程序显式计入 FE。
% 当 isRestart=true 时提高全局样本比例，以便停滞恢复跳出原有通道。

% 若调用方没有提供重启标志，则按普通初始化处理。
if nargin < 3
    % 默认不是停滞重启。
    isRestart = false;
end

% 读取问题配置副本。
cfg = problem.cfg;

% 读取归一化决策维数。
D = problem.dim;

% 创建初始化元数据结构。
meta = struct();

% 为每个个体预分配来源标签。
meta.source = cell(N, 1);

% 预留多通道种子折线路径。
meta.seedPaths = {};

% 记录本次初始化是否由停滞恢复触发。
meta.isRestart = isRestart;

% 若关闭地形初始化或问题不是 UAV 路径问题，则使用统一随机初始化。
if ~cfg.initialization.enabled || ~strcmpi(problem.kind, 'uav_path')
    % 在归一化超立方体内均匀生成 N 个个体。
    X = rand(N, D);

    % 给每个个体标记随机来源。
    meta.source(:) = {'random'};

    % 结束初始化。
    return;
end

% 根据是否为停滞重启选择三类样本比例。
if isRestart
    % 重启时减少种子依赖，增加全局构造样本比例。
    fractions = [0.20, 0.25, 0.55];
else
    % 普通初始化使用配置中冻结的种子、Tent 和全局比例。
    fractions = [cfg.initialization.seedFraction, ...
        cfg.initialization.localTentFraction, ...
        cfg.initialization.globalFraction];
end

% 把可能的负比例截断为零。
fractions = max(fractions, 0);

% 检查三个比例之和是否为正。
if sum(fractions) <= eps
    % 无有效比例时显式报错，避免除零和空种群。
    error('terrain_aware_initialization:InvalidFractions', ...
        'At least one initialization fraction must be positive.');
end

% 把三个比例归一化，使总和严格为 1。
fractions = fractions / sum(fractions);

% 先向下取整计算每类样本数量。
counts = floor(N .* fractions);

% 当取整后总数量小于 N 时，逐个补给当前欠配最多的类别。
while sum(counts) < N
    % 计算各类别理想比例与当前分配比例的差值。
    allocationDeficit = fractions - counts / max(N, 1);

    % 找出欠配最多的类别。
    [~, categoryIndex] = max(allocationDeficit);

    % 给该类别增加一个个体。
    counts(categoryIndex) = counts(categoryIndex) + 1;
end

% 防御性处理：若浮点或配置异常使总数量大于 N，则从最大类别中递减。
while sum(counts) > N
    % 找出当前数量最多的类别。
    [~, categoryIndex] = max(counts);

    % 从该类别移除一个个体。
    counts(categoryIndex) = counts(categoryIndex) - 1;
end

% 在粗粒度代价图上生成并去重多通道二维路径。
seedPaths = generate_seed_paths(problem.env, cfg, ...
    problem.physicalLB, problem.physicalUB);

% 把原始二维种子折线保存到元数据，便于可视化和复现实验。
meta.seedPaths = seedPaths;

% 创建编码后的归一化种子向量元胞数组。
seedZ = {};

% 逐条把二维折线转换为三维控制点并编码。
for seedIndex = 1:numel(seedPaths)
    % 按弧长把当前二维路径压缩为 K+2 个三维控制点。
    controlPoints = path_to_control_points(seedPaths{seedIndex}, ...
        problem.env, cfg);

    % 将 K 个内部三维控制点编码为归一化决策向量。
    encodedSeed = encode_control_points(controlPoints, cfg, ...
        problem.physicalLB, problem.physicalUB);

    % 对可能的微小越界执行镜像反射。
    encodedSeed = reflect_bounds(encodedSeed, 0, 1);

    % 保存当前归一化种子。
    seedZ{end + 1} = encodedSeed; %#ok<AGROW>
end

% 若 A* 未产生任何路径，则用构造式全局样本作为透明回退种子。
if isempty(seedZ)
    % 生成一个具备任务进度和地形高度先验的样本。
    seedZ = {constructive_global_sample(problem)};
end

% 预分配 N×D 归一化种群矩阵。
X = zeros(N, D);

% 初始化当前写入行号。
row = 0;

%% 第一部分：多通道种子组

% 按类别数量依次写入种子个体。
for i = 1:counts(1)
    % 移动到下一个种群行。
    row = row + 1;

    % 在可用种子之间循环分配，避免所有个体集中于第一条路径。
    seedId = mod(i - 1, numel(seedZ)) + 1;

    % 把当前归一化种子写入种群。
    X(row, :) = seedZ{seedId};

    % 记录当前个体来自哪一条种子路径。
    meta.source{row} = sprintf('seed_%d', seedId);
end

%% 第二部分：Tent 种子邻域组

% 生成配置数量的种子邻域扰动个体。
for i = 1:counts(2)
    % 移动到下一个种群行。
    row = row + 1;

    % 在不同种子之间循环选择扰动中心。
    seedId = mod(i - 1, numel(seedZ)) + 1;

    % 生成长度 D 的 Tent 混沌序列并中心化到约 [-0.5,0.5]。
    tent = reshape(tent_sequence(D, rand), 1, []) - 0.5;

    % 为每个维度独立生成 +1 或 -1 的对称方向。
    signVector = 2 .* (rand(1, D) >= 0.5) - 1;

    % 根据配置尺度构造逐维归一化扰动。
    perturbation = cfg.initialization.tentSigma .* signVector .* ...
        (2 .* abs(tent));

    % 将扰动叠加到对应种子并执行统一镜像反射。
    X(row, :) = reflect_bounds(seedZ{seedId} + perturbation, 0, 1);

    % 记录当前个体的来源标签。
    meta.source{row} = sprintf('tent_seed_%d', seedId);
end

%% 第三部分：构造式全局组

% 生成配置数量的全局通道探索个体。
for i = 1:counts(3)
    % 移动到下一个种群行。
    row = row + 1;

    % 生成一个具备任务进度但保留宽范围横向变化的样本。
    X(row, :) = constructive_global_sample(problem);

    % 记录当前个体来源。
    meta.source{row} = 'constructive_global';
end

% 防御性补齐：若比例舍入逻辑仍留下空行，则用构造式全局样本补齐。
while row < N
    % 移动到下一个空行。
    row = row + 1;

    % 填入构造式全局样本。
    X(row, :) = constructive_global_sample(problem);

    % 记录防御性补齐来源。
    meta.source{row} = 'constructive_global_fill';
end

% 最后检查种群尺寸是否严格为 N×D。
if ~isequal(size(X), [N, D])
    % 尺寸异常会破坏所有后续算法更新，因此显式报错。
    error('terrain_aware_initialization:PopulationSize', ...
        'Generated population size does not match N-by-D.');
end
end
