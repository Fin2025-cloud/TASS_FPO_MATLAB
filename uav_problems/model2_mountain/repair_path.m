function [candidates, info] = repair_path(z, result, env, cfg, ...
    physicalLB, physicalUB, maxRounds)
%REPAIR_PATH 按约束类型生成局部几何修复候选。
%
% 关键原则
% -------------------------------------------------------------------------
% 1) 本函数不调用 evaluate_path，因此不会隐藏任何 FE；
% 2) 正式主程序每次通常令 maxRounds=1，评价修复结果后再决定是否继续；
% 3) 修复顺序按硬碰撞优先：地形、静态、动态、边界、爬升、曲率；
% 4) 修复只生成候选，不强制接受，最终由主程序使用 Deb 规则选择；
% 5) 每轮归一化移动受 maxNormalizedMove 限制，防止修复器取代优化器。
%
% 输出 candidates 的每行是一个归一化候选；info 保存动作类型、影响位置和
% 移动幅度，供修复贡献分析和实验审计使用。

% 若未提供修复轮数，则默认只生成一轮候选。
if nargin < 7 || isempty(maxRounds)
    % 一轮一评价是严格 FE 计数的推荐方式。
    maxRounds = 1;
end

% 预分配空候选矩阵，每列对应一个决策维度。
candidates = zeros(0, numel(z));

% 创建修复日志结构。
info = struct();

% 初始化动作元胞数组。
info.actions = {};

% 初始化成功标志；只有输入本身可行时可在本函数直接标记成功。
info.success = false;

% 初始化已生成修复轮数。
info.rounds = 0;

% 初始化每轮归一化移动范数记录。
info.moveNorm = [];
if ~isfield(result,'basisMatrix')||~isfield(result.violation,'raw')||isempty(result.pathSamples)
    return; % invalid/degenerate candidates have no geometric repair evidence
end

% 把输入决策向量统一转换为行向量。
currentZ = double(z(:)');

% 保存与 currentZ 对应的完整评价结果。
currentResult = result;

% 最多生成 maxRounds 个几何修复候选。
for roundId = 1:maxRounds
    % 若当前结果已经可行，则无需继续修复。
    if currentResult.isFeasible
        % 标记修复目标已满足。
        info.success = true;

        % 结束修复循环。
        break;
    end

    % 根据当前最优先违反类型生成一个修复位置。
    [newZ, action] = one_repair_step(currentZ, currentResult, env, cfg, ...
        physicalLB, physicalUB);

    % 若无法生成候选或移动小于数值阈值，则停止。
    if isempty(newZ) || norm(newZ - currentZ) < 1e-14
        % 结束修复循环。
        break;
    end

    % 把新候选追加到候选矩阵。
    candidates(end + 1, :) = newZ; %#ok<AGROW>

    % 保存本轮修复动作详情。
    info.actions{end + 1} = action; %#ok<AGROW>

    % 保存本轮归一化位置移动范数。
    info.moveNorm(end + 1) = norm(newZ - currentZ); %#ok<AGROW>

    % 保存已生成的修复轮数。
    info.rounds = roundId;

    % 将几何候选作为下一轮输入位置。
    currentZ = newZ;

    % 注意：本函数没有重新评价 newZ，因此 currentResult 仍对应上一位置。
    % 正式主程序保持 maxRounds=1，并在 evaluate_with_repair 中评价后再次调用。
end
end

function [newZ, action] = one_repair_step(z, result, env, cfg, ...
    physicalLB, physicalUB)
%ONE_REPAIR_STEP 根据最高优先级违反生成一个修复候选。

% 创建默认无动作日志。
action = struct('type', 'none', 'sampleIndex', 0, ...
    'controlIndices', [], 'deltaPhysical', [0, 0, 0]);

% 读取包含固定起终点的完整控制点矩阵。
controlPoints = result.controlPoints;

% 读取 B 样条基函数矩阵，用于把轨迹点位移分配给内部控制点。
basis = result.basisMatrix;

% 读取三维轨迹采样点。
pathPoints = result.pathSamples;

% 读取各类物理约束违反量。
raw = result.violation.raw;

%% 1) 地形净空修复

% 当允许地形修复且存在净空不足时优先处理。
if cfg.repair.allowTerrain && raw.terrain > 0
    % 读取最严重地形违反对应的轨迹采样点索引。
    sampleIndex = result.details.terrainWorstIndex;

    % 构造沿正 z 方向的物理抬升量，并增加修复裕度。
    physicalDelta = [0, 0, raw.terrain + cfg.repair.margin];

    % 按基函数权重把轨迹点抬升分配给相关内部控制点。
    [controlPoints, action] = distribute_delta(controlPoints, basis, ...
        sampleIndex, physicalDelta, cfg, 'terrain');

    % 重新编码并限制本轮归一化移动。
    newZ = finalize(controlPoints, z, cfg, physicalLB, physicalUB);

    % 地形修复完成后直接返回，不同时处理其他违反类型。
    return;
end

%% 2) 静态障碍修复

% 当允许静态修复且存在静态安全距离不足时处理。
if cfg.repair.allowStatic && raw.static > 0
    % 读取静态障碍连续碰撞检查详情。
    staticDetail = result.details.static;

    % 把最严重线段索引限制到轨迹采样范围内。
    sampleIndex = max(1, min(size(pathPoints, 1), ...
        staticDetail.worstSegment));

    % 读取造成最严重违反的静态障碍。
    obstacle = env.staticObstacles(staticDetail.worstObstacle);

    % 计算最危险轨迹点相对圆柱中心的水平径向向量。
    radial = staticDetail.worstPoint(1:2) - obstacle.center;

    % 若危险点位于圆柱高度范围且水平法向有效，则沿水平方向外推。
    if staticDetail.worstPoint(3) >= obstacle.zMin && ...
            staticDetail.worstPoint(3) <= obstacle.zMax && ...
            norm(radial) > 1e-8
        % 归一化水平径向并补零垂直分量。
        direction = [radial / norm(radial), 0];

    % 若危险点位于圆柱上端盖上方，则继续向上修复。
    elseif staticDetail.worstPoint(3) > obstacle.zMax
        % 选择正 z 方向。
        direction = [0, 0, 1];

    % 若危险点位于圆柱下端盖下方，则向下远离障碍。
    elseif staticDetail.worstPoint(3) < obstacle.zMin
        % 选择负 z 方向。
        direction = [0, 0, -1];

    % 高度关系退化但水平径向有效时仍沿径向外推。
    elseif norm(radial) > 1e-8
        % 归一化水平径向。
        direction = [radial / norm(radial), 0];
    else
        % 位于圆柱轴线附近时水平法向不稳定，使用向上方向回退。
        direction = [0, 0, 1];
    end

    % 根据违反缺口和修复裕度计算物理位移。
    physicalDelta = direction .* (raw.static + cfg.repair.margin);

    % 按基函数权重把位移分配给相关内部控制点。
    [controlPoints, action] = distribute_delta(controlPoints, basis, ...
        sampleIndex, physicalDelta, cfg, 'static');

    % 重新编码并限制本轮归一化移动。
    newZ = finalize(controlPoints, z, cfg, physicalLB, physicalUB);

    % 静态障碍修复完成后返回。
    return;
end

%% 3) 动态障碍修复

% 当允许动态修复且存在时空安全距离不足时处理。
if cfg.repair.allowDynamic && raw.dynamic > 0
    % 读取动态连续碰撞检查详情。
    dynamicDetail = result.details.dynamic;

    % 把最严重动态冲突线段映射为合法采样索引。
    sampleIndex = max(1, min(size(pathPoints, 1), ...
        dynamicDetail.worstSegment));

    % 计算最危险时刻 UAV 位置到障碍位置的三维分离向量。
    separation = dynamicDetail.worstPoint - dynamicDetail.obstaclePoint;

    % 提取水平分离向量。
    horizontalSeparation = separation(1:2);

    % 若水平分离方向稳定，则优先做平面侧移。
    if norm(horizontalSeparation) > 1e-8
        % 归一化水平分离向量并补零垂直分量。
        direction = [horizontalSeparation / norm(horizontalSeparation), 0];
    else
        % 水平位置近似重合时选择向上抬升。
        direction = [0, 0, 1];
    end

    % 根据动态安全距离缺口与修复裕度计算位移。
    physicalDelta = direction .* (raw.dynamic + cfg.repair.margin);

    % 按基函数权重把动态避障位移分配给内部控制点。
    [controlPoints, action] = distribute_delta(controlPoints, basis, ...
        sampleIndex, physicalDelta, cfg, 'dynamic');

    % 重新编码并限制本轮归一化移动。
    newZ = finalize(controlPoints, z, cfg, physicalLB, physicalUB);

    % 动态障碍修复完成后返回。
    return;
end

%% 4) 归一化边界修复

% 边界违反通常已由优化器反射处理，此处只提供防御性回退。
if raw.boundary > 0
    % 把所有越界维度通过镜像反射映射回 [0,1]。
    newZ = reflect_bounds(z, 0, 1);

    % 记录边界修复动作类型。
    action.type = 'boundary';

    % 返回边界修复候选。
    return;
end

%% 5) 爬升角修复

% 当允许爬升修复且存在爬升角超限时处理。
if cfg.repair.allowClimb && raw.climb > 0
    % 计算每条线段的爬升角超限量并定位最严重线段。
    [~, segmentIndex] = max(max(0, ...
        abs(result.details.climbAngle) - cfg.uav.maxClimbAngle));

    % 将线段索引映射到相邻轨迹采样点。
    sampleIndex = min(size(basis, 1), segmentIndex + 1);

    % 读取该采样点对所有内部控制点的基函数权重。
    weights = basis(sampleIndex, 2:end-1);

    % 找到对该轨迹点贡献最大的内部控制点。
    [~, localControlIndex] = max(weights);

    % 转换为完整控制点矩阵中的行号。
    controlIndex = localControlIndex + 1;

    % 只有真正的内部控制点才允许移动。
    if controlIndex > 1 && controlIndex < size(controlPoints, 1)
        % 用相邻控制点高度构造局部加权平滑目标。
        targetZ = (controlPoints(controlIndex - 1, 3) + ...
            2 * controlPoints(controlIndex, 3) + ...
            controlPoints(controlIndex + 1, 3)) / 4;

        % 构造只改变高度的物理位移。
        physicalDelta = [0, 0, ...
            targetZ - controlPoints(controlIndex, 3)];

        % 按该控制点的物理边界跨度限制位移。
        physicalDelta = limit_physical_delta(physicalDelta, ...
            controlIndex, cfg, physicalLB, physicalUB);

        % 以 stepGain 比例应用局部高度修复。
        controlPoints(controlIndex, :) = controlPoints(controlIndex, :) + ...
            cfg.repair.stepGain .* physicalDelta;

        % 记录动作类型。
        action.type = 'climb';

        % 记录对应轨迹采样点。
        action.sampleIndex = sampleIndex;

        % 记录被移动控制点。
        action.controlIndices = controlIndex;

        % 记录实际应用的物理位移。
        action.deltaPhysical = cfg.repair.stepGain .* physicalDelta;
    end

    % 重新编码并限制归一化移动。
    newZ = finalize(controlPoints, z, cfg, physicalLB, physicalUB);

    % 爬升修复完成后返回。
    return;
end

%% 6) 曲率修复

% 当允许曲率修复且存在曲率超限时处理。
if cfg.repair.allowCurvature && raw.curvature > 0
    % 计算每个内部轨迹点的曲率超限量并定位最严重位置。
    [~, curvatureIndex] = max(max(0, ...
        result.details.curvature - cfg.uav.maxCurvature));

    % 将内部曲率索引映射到轨迹采样点索引。
    sampleIndex = min(size(basis, 1), curvatureIndex + 1);

    % 读取该采样点对所有内部控制点的基函数权重。
    weights = basis(sampleIndex, 2:end-1);

    % 找到贡献最大的内部控制点。
    [~, localControlIndex] = max(weights);

    % 转换为完整控制点矩阵行号。
    controlIndex = localControlIndex + 1;

    % 只有内部控制点允许移动。
    if controlIndex > 1 && controlIndex < size(controlPoints, 1)
        % 取相邻两个控制点中点作为平滑目标。
        targetPoint = 0.5 .* (controlPoints(controlIndex - 1, :) + ...
            controlPoints(controlIndex + 1, :));

        % 计算当前控制点指向平滑目标的位移。
        physicalDelta = targetPoint - controlPoints(controlIndex, :);

        % 根据物理变量跨度限制三维位移。
        physicalDelta = limit_physical_delta(physicalDelta, ...
            controlIndex, cfg, physicalLB, physicalUB);

        % 按 stepGain 应用曲率修复。
        controlPoints(controlIndex, :) = controlPoints(controlIndex, :) + ...
            cfg.repair.stepGain .* physicalDelta;

        % 记录动作类型。
        action.type = 'curvature';

        % 记录对应轨迹采样点。
        action.sampleIndex = sampleIndex;

        % 记录被移动控制点。
        action.controlIndices = controlIndex;

        % 记录实际应用物理位移。
        action.deltaPhysical = cfg.repair.stepGain .* physicalDelta;
    end

    % 重新编码并限制归一化移动。
    newZ = finalize(controlPoints, z, cfg, physicalLB, physicalUB);

    % 曲率修复完成后返回。
    return;
end

% 没有可处理违反类型时返回空候选。
newZ = [];
end

function [controlPoints, action] = distribute_delta(controlPoints, basis, ...
    sampleIndex, physicalDelta, cfg, actionType)
%DISTRIBUTE_DELTA 按 B 样条基函数权重分配轨迹点修复位移。

% 读取目标采样点对所有内部控制点的权重。
weights = basis(sampleIndex, 2:end-1);

% 找到权重大于数值阈值的有效内部控制点。
active = find(weights > 1e-6);

% 创建动作日志结构。
action = struct('type', actionType, 'sampleIndex', sampleIndex, ...
    'controlIndices', active + 1, 'deltaPhysical', physicalDelta);

% 若没有有效内部控制点，则保持控制点不变。
if isempty(active)
    % 结束函数。
    return;
end

% 使用权重平方和作为位移分配归一化因子。
normalizer = sum(weights(active) .^ 2) + eps;

% 逐个移动与目标轨迹点相关的内部控制点。
for localIndex = active
    % 转换为完整控制点矩阵行号。
    controlIndex = localIndex + 1;

    % 根据基函数权重计算当前控制点承担的物理位移。
    move = cfg.repair.stepGain .* ...
        (weights(localIndex) / normalizer) .* physicalDelta;

    % 把位移应用到当前内部控制点。
    controlPoints(controlIndex, :) = controlPoints(controlIndex, :) + move;
end
end

function physicalDelta = limit_physical_delta(physicalDelta, controlIndex, ...
    cfg, physicalLB, physicalUB)
%LIMIT_PHYSICAL_DELTA 把归一化最大移动换算为当前控制点物理位移上限。

% 计算当前内部控制点在 1×3K 物理边界中的三个变量索引。
baseIndex = (controlIndex - 2) * 3 + (1:3);

% 计算该控制点三个坐标的物理跨度。
physicalSpan = physicalUB(baseIndex) - physicalLB(baseIndex);

% 将归一化移动上限换算为三个坐标的物理上限。
physicalLimit = cfg.repair.maxNormalizedMove .* physicalSpan;

% 逐维截断物理位移。
physicalDelta = max(-physicalLimit, min(physicalLimit, physicalDelta));
end

function newZ = finalize(controlPoints, oldZ, cfg, physicalLB, physicalUB)
%FINALIZE 将修复后的控制点编码、限制单轮移动并反射到归一化边界。

% 将修复后的完整控制点重新编码为归一化决策向量。
encoded = encode_control_points(controlPoints, cfg, physicalLB, physicalUB);

% 计算相对原候选的归一化位移。
move = encoded - oldZ;

% 逐维限制本轮最大归一化移动，防止修复器执行过强全局跳跃。
move = max(-cfg.repair.maxNormalizedMove, ...
    min(cfg.repair.maxNormalizedMove, move));

% 把受限位移叠加到原位置并执行镜像边界处理。
newZ = reflect_bounds(oldZ + move, 0, 1);
end
