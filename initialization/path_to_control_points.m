function controlPoints = path_to_control_points(xyPath, env, cfg)
%PATH_TO_CONTROL_POINTS 将二维粗路径压缩为固定数量的三维 B 样条控制点。
%
% 理论作用
% -------------------------------------------------------------------------
% A* 在粗二维网格上输出若干离散折线点，但 TAAS-FPO 优化的是 K 个内部三维
% 控制点。因此，本函数先按弧长对二维折线重采样为 K+2 个点，再利用 DEM
% 高度、最小净空和额外安全裕度生成对应高度。输出首尾两点固定为任务起点
% 与终点，中间 K 点作为后续编码和优化变量。
%
% 实验真实性说明
% -------------------------------------------------------------------------
% 1) 本函数只构造初始控制点，不调用目标函数，因此不产生隐藏 FE；
% 2) 高度平滑只用于初始化，不改变后续统一评价器的碰撞和约束判定；
% 3) 平滑后再次执行净空下界保护，避免平滑把控制点压入地形；
% 4) 最终 B 样条是否可行仍由 evaluate_path 统一判断，不能把本函数输出直接
%    当作“已验证可行路径”。

% 从配置结构中读取内部控制点数量 K。
K = cfg.path.K;

% 若输入路径少于两个点，则无法形成有效折线，使用起终点直线作为透明回退。
if size(xyPath, 1) < 2
    % 将固定起点和终点的平面坐标组成两点折线。
    xyPath = [env.start(1:2); env.goal(1:2)];
end

% 计算相邻二维路径点之间的欧氏距离，得到每个折线段长度。
segmentLength = vecnorm(diff(xyPath, 1, 1), 2, 2);

% 对折线段长度累加，构造从 0 开始的累计弧长参数。
s = [0; cumsum(segmentLength)];

% 判断整条输入折线是否退化为几乎同一个点。
if s(end) <= eps
    % 在 [0,1] 上均匀生成 K+2 个插值参数，包括固定首尾点。
    t = linspace(0, 1, K + 2)';

    % 使用显式 bsxfun 进行二维线性插值，避免行列方向或 MATLAB 版本差异。
    xyFromStart = bsxfun(@times, 1 - t, env.start(1:2));

    % 计算终点对各插值参数的加权贡献。
    xyFromGoal = bsxfun(@times, t, env.goal(1:2));

    % 合并起点和终点贡献，得到 K+2 个二维直线采样点。
    xy = xyFromStart + xyFromGoal;
else
    % 在总弧长区间内均匀选取 K+2 个目标弧长位置。
    targetArcLength = linspace(0, s(end), K + 2)';

    % 沿累计弧长分别线性插值 x 坐标。
    xInterp = interp1(s, xyPath(:, 1), targetArcLength, 'linear');

    % 沿累计弧长分别线性插值 y 坐标。
    yInterp = interp1(s, xyPath(:, 2), targetArcLength, 'linear');

    % 将插值得到的 x、y 列组合为 K+2 行二维坐标。
    xy = [xInterp, yInterp];
end

% 查询每个二维控制点位置对应的地形高度。
terrainAtControl = terrain_height(env, xy(:, 1), xy(:, 2));

% 若个别查询点超出 DEM 或插值失败，使用环境最低高度作为可追踪的防御值。
terrainAtControl(~isfinite(terrainAtControl)) = env.zLim(1);

% 在地形高度之上叠加法定/任务净空和初始化额外裕度，构造初始高度。
z = terrainAtControl + cfg.constraint.clearance + 25;

% 强制第一个控制点高度等于任务固定起点高度。
z(1) = env.start(3);

% 强制最后一个控制点高度等于任务固定终点高度。
z(end) = env.goal(3);

% 当控制点足够多时，仅对内部高度执行三点移动平均，降低初始急剧爬升。
if numel(z) >= 5
    % 先对完整高度向量计算移动平均，保持输出长度与 z 完全一致。
    zSmoothed = movmean(z, 3, 'Endpoints', 'shrink');

    % 只把平滑后的内部元素写回，首尾固定高度保持不变。
    % 旧版本错误地把长度 K+2 的 zSmoothed 直接赋给长度 K 的内部区间，
    % 会触发 MATLAB:matrix:singleSubscriptNumelMismatch。
    z(2:end-1) = zSmoothed(2:end-1);
end

% 计算每个控制点必须满足的最低安全高度，并额外保留 5 m 初始化裕度。
minimumSafeZ = terrainAtControl + cfg.constraint.clearance + 5;

% 对平滑结果施加逐点下界，避免移动平均把控制点压低到净空以下。
z = max(z, minimumSafeZ);

% 将二维坐标与高度列组合成完整的三维控制点矩阵。
controlPoints = [xy, z];

% 再次覆盖首控制点，确保它与环境起点在三个坐标上完全一致。
controlPoints(1, :) = env.start;

% 再次覆盖尾控制点，确保它与环境终点在三个坐标上完全一致。
controlPoints(end, :) = env.goal;
end
