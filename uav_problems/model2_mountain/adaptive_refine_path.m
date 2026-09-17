function path = adaptive_refine_path(path, env, cfg)
%ADAPTIVE_REFINE_PATH 对危险或几何变化明显的 B 样条区段进行参数加密。
%
% 理论作用
% -------------------------------------------------------------------------
% 固定数量的均匀采样点可能漏检窄障碍、陡峭地形或局部高曲率。该函数只在
% 参数域中插入新的 u 中点，再通过同一 B 样条基函数重新计算轨迹点。它不会
% 改变控制点、优化变量或目标函数定义，因此属于评价精度增强而不是搜索算子。
%
% 触发条件
% -------------------------------------------------------------------------
% 1) 线段长度超过 maxSegmentLength；
% 2) 线段两端至少一个点的地形净空较低；
% 3) 内部三点转角超过采样触发阈值。
%
% 所有新采样点都属于同一次 evaluate_path 调用，因此不额外计 FE。

% 若配置关闭自适应采样，直接返回原始路径。
if ~cfg.path.enableAdaptiveSampling
    % 不做任何数据修改。
    return;
end

% 最多执行配置给定的递归细分轮数。
for roundId = 1:cfg.path.maxRefineRounds
    % 读取当前轮的三维轨迹采样点。
    P = path.P;

    % 读取当前轮每个采样点对应的 B 样条参数。
    u = path.u(:);

    % 读取当前采样点数量。
    n = size(P, 1);

    % 若已达到允许的最大采样点数，则停止继续加密。
    if n >= cfg.path.maxAdaptivePoints
        % 跳出细分循环。
        break;
    end

    % 计算当前所有相邻采样点之间的线段长度。
    ds = vecnorm(diff(P, 1, 1), 2, 2);

    % 查询当前所有采样点的地形高度。
    terrainH = terrain_height(env, P(:, 1), P(:, 2));

    % 强制地形高度为列向量。
    terrainH = terrainH(:);

    % 对地图外点赋予正无穷地形高度，使相邻区段必然触发细分并最终被判违反。
    terrainH(~isfinite(terrainH)) = inf;

    % 计算所有采样点的地形净空。
    clearance = P(:, 3) - terrainH;

    % 首先标记长度超过阈值的轨迹线段。
    refine = ds > cfg.path.maxSegmentLength;

    % 计算每条线段两个端点中的较小净空。
    minimumSegmentClearance = min(clearance(1:end-1), clearance(2:end));

    % 标记净空低于指定倍数安全净空的线段。
    nearTerrain = minimumSegmentClearance < ...
        cfg.path.clearanceRefineFactor * cfg.constraint.clearance;

    % 合并长线段和低净空线段标记。
    refine = refine | nearTerrain;

    % 至少有三个点时，进一步识别高转角趋势。
    if n >= 3
        % 计算每个内部点之前的线段向量。
        previousVector = P(2:end-1, :) - P(1:end-2, :);

        % 计算每个内部点之后的线段向量。
        nextVector = P(3:end, :) - P(2:end-1, :);

        % 计算相邻线段夹角余弦。
        cosineAngle = sum(previousVector .* nextVector, 2) ./ ...
            (vecnorm(previousVector, 2, 2) .* vecnorm(nextVector, 2, 2) + eps);

        % 把余弦限制到合法区间后求转角。
        angle = acos(max(-1, min(1, cosineAngle)));

        % 用约 11.5° 的阈值识别需要更密采样的局部转向。
        highTurn = angle > 0.20;

        % 把内部转角索引转换为对应轨迹点索引。
        highTurnPointIndex = find(highTurn) + 1;

        % 依次把高转角点前后的两条线段标记为待细分。
        for k = 1:numel(highTurnPointIndex)
            % 读取当前高转角轨迹点索引。
            pointIndex = highTurnPointIndex(k);

            % 计算前一条线段索引，并限制在合法范围内。
            previousSegment = max(1, pointIndex - 1);

            % 计算后一条线段索引，并限制在合法范围内。
            nextSegment = min(numel(refine), pointIndex);

            % 标记前一条线段需要细分。
            refine(previousSegment) = true;

            % 标记后一条线段需要细分。
            refine(nextSegment) = true;
        end
    end

    % 取得全部待细分线段的索引。
    refineIndex = find(refine);

    % 若没有任何线段触发条件，则提前结束细分。
    if isempty(refineIndex)
        % 跳出细分循环。
        break;
    end

    % 计算本轮还允许新增的采样点数量。
    remainingCapacity = cfg.path.maxAdaptivePoints - n;

    % 若触发线段数量超过剩余容量，只保留前若干个确定性索引。
    if numel(refineIndex) > remainingCapacity
        % 截断索引不会引入随机性，保证可复现。
        refineIndex = refineIndex(1:remainingCapacity);
    end

    % 对每条待细分线段计算参数中点。
    newU = 0.5 .* (u(refineIndex) + u(refineIndex + 1));

    % 合并旧参数和新参数并升序排列。
    u = sort([u; newU]);

    % 在新参数集合上重新计算 B 样条基函数矩阵。
    B = bspline_basis_matrix(u, size(path.controlPoints, 1), ...
        path.degree, path.knots);

    % 更新路径参数向量。
    path.u = u;

    % 更新路径基函数矩阵。
    path.basis = B;

    % 使用同一控制点矩阵重新生成加密后的轨迹采样点。
    path.P = B * path.controlPoints;
end
end
