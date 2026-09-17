function paths = generate_seed_paths(env, cfg, physicalLB, physicalUB) %#ok<INUSD>
%GENERATE_SEED_PATHS 在粗二维代价图上生成并去重多通道 A* 路径。
%
% 代价图包含地形坡度、相对高度和静态障碍风险。多组固定权重及确定性空间
% 扰动使 A* 倾向不同山谷通道。输出只包含二维折线，不进行完整三维评价；
% 后续 path_to_control_points 负责赋予高度，evaluate_path 负责最终可行性判定。

% 读取粗网格尺寸 [nx,ny]。
gridSize = cfg.initialization.gridSize;

% 读取 x 方向网格数量。
nx = gridSize(1);

% 读取 y 方向网格数量。
ny = gridSize(2);

% 在环境 x 范围内生成规则网格坐标。
x = linspace(env.xLim(1), env.xLim(2), nx);

% 在环境 y 范围内生成规则网格坐标。
y = linspace(env.yLim(1), env.yLim(2), ny);

% 生成二维网格坐标矩阵。
[X, Y] = meshgrid(x, y);

% 查询粗网格上的地形高度。
Z = terrain_height(env, X, Y);

% 找出有限地形高度值。
finiteTerrain = Z(isfinite(Z));

% 若不存在有限值，说明 DEM 配置完全无效。
if isempty(finiteTerrain)
    % 直接报错，避免构造没有物理意义的代价图。
    error('generate_seed_paths:InvalidTerrain', ...
        'The terrain grid contains no finite height values.');
end

% 把非有限地形位置设为高于当前最高地形 100 m 的大代价区域。
Z(~isfinite(Z)) = max(finiteTerrain) + 100;

% 计算地形高度在 y、x 方向的数值梯度。
[gradientY, gradientX] = gradient(Z, mean(diff(y)), mean(diff(x)));

% 计算坡度幅值。
slope = sqrt(gradientX .^ 2 + gradientY .^ 2);

% 把坡度归一化到近似 [0,1]。
slope = slope / (max(slope(:)) + eps);

% 取得地形最小高度。
minimumHeight = min(Z(:));

% 取得地形最大高度。
maximumHeight = max(Z(:));

% 把相对高度归一化到 [0,1]。
height = (Z - minimumHeight) / (maximumHeight - minimumHeight + eps);

% 初始化静态障碍软风险图。
risk = zeros(size(Z));

% 初始化完全不可通行网格标志。
blocked = false(size(Z));

% 将所有静态圆柱障碍投影到二维粗代价图。
for obstacleIndex = 1:numel(env.staticObstacles)
    % 读取当前障碍。
    obstacle = env.staticObstacles(obstacleIndex);

    % 非圆柱障碍由其他扩展接口处理，这里跳过。
    if ~strcmpi(obstacle.type, 'cylinder')
        % 继续处理下一个障碍。
        continue;
    end

    % 计算每个网格点到圆柱水平边界的有符号距离。
    obstacleDistance = hypot(X - obstacle.center(1), ...
        Y - obstacle.center(2)) - obstacle.radius;

    % 以 50 m 衰减尺度累加障碍附近软风险。
    risk = risk + exp(-max(obstacleDistance, 0) / 50);

    % 若障碍高度覆盖整个允许飞行高度，则把安全膨胀区域标记为不可通行。
    if obstacle.zMax + cfg.uav.radius + cfg.constraint.staticSafety >= env.zLim(2)
        % 计算 UAV 包络与安全距离之和。
        safetyExpansion = cfg.uav.radius + cfg.constraint.staticSafety;

        % 合并当前障碍的二维阻塞区域。
        blocked = blocked | obstacleDistance < safetyExpansion;
    end
end

% 把累计静态风险归一化到近似 [0,1]。
risk = risk / (max(risk(:)) + eps);

% 找到距离起点 x 坐标最近的粗网格列。
[~, startColumn] = min(abs(x - env.start(1)));

% 找到距离起点 y 坐标最近的粗网格行。
[~, startRow] = min(abs(y - env.start(2)));

% 找到距离终点 x 坐标最近的粗网格列。
[~, goalColumn] = min(abs(x - env.goal(1)));

% 找到距离终点 y 坐标最近的粗网格行。
[~, goalRow] = min(abs(y - env.goal(2)));

% 组合 A* 使用的起点 [row,column]。
startRC = [startRow, startColumn];

% 组合 A* 使用的终点 [row,column]。
goalRC = [goalRow, goalColumn];

% 读取多组固定代价权重。
weightSets = cfg.initialization.seedWeightSets;

% 计算最终希望保留的最大种子路径数量。
numberWanted = min(cfg.initialization.numSeedPaths, size(weightSets, 1));

% 创建种子路径元胞数组。
paths = {};

% 计算地图对角线长度，用于 Hausdorff 距离无量纲化。
mapDiagonal = hypot(diff(env.xLim), diff(env.yLim));

% 逐组使用不同代价权重搜索候选通道。
for weightIndex = 1:size(weightSets, 1)
    % 读取当前三元代价权重。
    weights = weightSets(weightIndex, :);

    % 为当前权重组构造确定性空间扰动相位。
    phase = 0.73 * weightIndex;

    % 构造 x 方向确定性扰动行向量。
    noiseX = sin((1:nx) * phase);

    % 构造 y 方向确定性扰动列向量。
    noiseY = cos((1:ny)' * (phase + 0.31));

    % 显式组合二维扰动矩阵，避免行列隐式扩展歧义。
    deterministicNoise = cfg.initialization.seedNoise .* ...
        bsxfun(@plus, noiseY, noiseX) ./ 2;

    % 汇总基础移动、坡度、风险、相对高度和微扰得到网格代价。
    cellCost = 1 + weights(2) .* slope + weights(3) .* risk + ...
        0.15 .* height + deterministicNoise;

    % 将完全阻塞网格设为无穷代价。
    cellCost(blocked) = inf;

    % 在当前代价图上执行 8 邻域 A*。
    rcPath = astar_grid(cellCost, startRC, goalRC, ...
        cfg.initialization.maxAstarExpansions);

    % A* 未找到路径时继续尝试下一组权重。
    if isempty(rcPath)
        % 跳过本次候选。
        continue;
    end

    % 根据 A* 列索引提取 x 坐标并转换为列向量。
    pathX = x(rcPath(:, 2));
    pathX = pathX(:);

    % 根据 A* 行索引提取 y 坐标并转换为列向量。
    pathY = y(rcPath(:, 1));
    pathY = pathY(:);

    % 组合二维候选折线。
    xy = [pathX, pathY];

    % 计算相邻路径点距离，识别重复点。
    adjacentDistance = vecnorm(diff(xy, 1, 1), 2, 2);

    % 保留第一个点及所有与前一点距离大于微小阈值的点。
    keep = [true; adjacentDistance > 1e-9];

    % 删除连续重复点。
    xy = xy(keep, :);

    % 初始化当前候选是否与已有通道重复的标志。
    duplicate = false;

    % 与所有已保留通道比较无量纲 Hausdorff 距离。
    for existingIndex = 1:numel(paths)
        % 计算当前候选与已有路径的对称 Hausdorff 距离。
        distance = path_hausdorff_distance(xy, paths{existingIndex});

        % 用地图对角线无量纲化路径差异。
        normalizedDistance = distance / max(mapDiagonal, eps);

        % 差异低于阈值时认为两条路径属于同一几何通道。
        if normalizedDistance < cfg.initialization.hausdorffThreshold
            % 标记为重复。
            duplicate = true;

            % 无需继续比较其他路径。
            break;
        end
    end

    % 只有非重复候选才加入种子集合。
    if ~duplicate
        % 保存当前二维通道。
        paths{end + 1} = xy; %#ok<AGROW>
    end

    % 达到目标种子数量后提前结束搜索。
    if numel(paths) >= numberWanted
        % 跳出权重循环。
        break;
    end
end

% 若所有 A* 搜索均失败，则使用二维直线作为透明回退。
if isempty(paths)
    % 生成至少 20 个直线插值参数。
    t = linspace(0, 1, max(20, cfg.path.K * 4))';

    % 显式计算起点水平坐标贡献。
    fromStart = bsxfun(@times, 1 - t, env.start(1:2));

    % 显式计算终点水平坐标贡献。
    fromGoal = bsxfun(@times, t, env.goal(1:2));

    % 保存直线回退路径，但不声称其满足障碍和地形约束。
    paths = {fromStart + fromGoal};
end
end
