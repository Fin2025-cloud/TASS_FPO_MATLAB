function risk = compute_risk(P, time, clearance, env, cfg)
%COMPUTE_RISK 计算沿轨迹弧长积分的连续软安全风险。
%
% 硬碰撞由 CV 和 Deb 可行性规则处理；风险目标只在安全距离之外继续区分
% “贴近危险源”和“保留更大裕度”的轨迹。风险由地形、静态障碍和动态
% 障碍三部分组成，并以线段长度为离散积分权重。

% 计算每条轨迹线段长度，并在末尾补零以与轨迹点数量对齐。
ds = [vecnorm(diff(P, 1, 1), 2, 2); 0];

% 强制净空为列向量，避免与其他点风险项的方向不一致。
clearance = clearance(:);

% 根据净空指数衰减计算地形风险，净空越小风险越大。
terrainRisk = exp(-max(clearance, 0) / max(cfg.risk.terrainScale, eps));

% 初始化每个轨迹点的静态障碍风险。
staticRisk = zeros(size(P, 1), 1);

% 依次累加每个静态障碍产生的风险场。
for q = 1:numel(env.staticObstacles)
    % 读取当前静态障碍。
    obstacle = env.staticObstacles(q);

    % 当前实现只对有限高度圆柱定义连续软风险。
    if strcmpi(obstacle.type, 'cylinder')
        % 计算轨迹点到圆柱侧面的有符号水平距离。
        horizontalDistance = hypot(P(:, 1) - obstacle.center(1), ...
            P(:, 2) - obstacle.center(2)) - obstacle.radius;

        % 计算轨迹点到圆柱上下端盖区间的垂直距离。
        verticalDistance = max([obstacle.zMin - P(:, 3), ...
            P(:, 3) - obstacle.zMax, zeros(size(P, 1), 1)], [], 2);

        % 合成轨迹点到有限圆柱表面的欧氏距离。
        obstacleDistance = hypot(max(horizontalDistance, 0), verticalDistance);

        % 按距离指数衰减并累加当前障碍的风险贡献。
        staticRisk = staticRisk + exp(-max(obstacleDistance, 0) / ...
            max(cfg.risk.staticScale, eps));
    end
end

% 初始化每个轨迹点的动态障碍风险。
dynamicRisk = zeros(size(P, 1), 1);

% 强制到达时间为列向量。
time = time(:);

% 依次累加每个动态障碍产生的时空风险。
for m = 1:numel(env.dynamicObstacles)
    % 读取当前动态障碍参数。
    obstacle = env.dynamicObstacles(m);

    % 用显式按行乘法计算每个到达时刻的障碍位移。
    obstacleDisplacement = bsxfun(@times, time, obstacle.velocity(:)');

    % 将初始位置复制到所有时间点并叠加位移，得到障碍轨迹。
    obstaclePosition = bsxfun(@plus, obstacleDisplacement, obstacle.p0(:)');

    % 计算 UAV 轨迹点到动态障碍中心的距离，并减去障碍半径。
    obstacleDistance = vecnorm(P - obstaclePosition, 2, 2) - obstacle.radius;

    % 按距离指数衰减并累加动态风险贡献。
    dynamicRisk = dynamicRisk + exp(-max(obstacleDistance, 0) / ...
        max(cfg.risk.dynamicScale, eps));
end

% 合并地形、静态障碍和动态障碍三类点风险。
integrand = terrainRisk + staticRisk + dynamicRisk;

% 用线段长度作为积分权重，计算整条路径的软风险积分。
risk = sum(integrand .* ds);
end
