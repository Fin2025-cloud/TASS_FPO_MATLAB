function z = constructive_global_sample(problem)
%CONSTRUCTIVE_GLOBAL_SAMPLE 生成带任务进度和地形净空的全局初始化样本。
%
% 理论目的
% -------------------------------------------------------------------------
% 对每个 x、y、z 坐标完全独立均匀采样，通常会产生大量折返、穿山和剧烈
% 爬升的无效轨迹。本函数保留“全局探索”所需的通道差异，同时施加三个弱
% 几何先验：
%   1) 控制点总体从起点向终点单调推进；
%   2) 平面扰动主要沿任务方向的法向展开，以探索不同山谷通道；
%   3) 高度由局部 DEM、最小净空和随机裕度共同构造。
% 这些先验只用于初始化，不改变统一评价器，也不保证样本必然可行。
%
% 数值稳健性
% -------------------------------------------------------------------------
% 本版本使用 bsxfun 显式扩展行列维度，避免不同 MATLAB 版本或输入方向造成
% “矩阵维度必须一致”错误。所有最终坐标仍由 encode_control_points 编码到
% [0,1]^D，并经过统一反射边界处理。

% 读取该问题冻结的配置结构。
cfg = problem.cfg;

% 读取该问题冻结的环境结构。
env = problem.env;

% 读取内部控制点数量 K。
K = cfg.path.K;

% 在 0 与 1 之间生成 K 个不包含首尾端点的任务进度参数。
t = (1:K)' / (K + 1);

% 读取三维固定起点。
startPoint = env.start;

% 读取三维固定终点。
goalPoint = env.goal;

% 计算各进度参数下起点的线性插值贡献，结果为 K×3。
fromStart = bsxfun(@times, 1 - t, startPoint);

% 计算各进度参数下终点的线性插值贡献，结果为 K×3。
fromGoal = bsxfun(@times, t, goalPoint);

% 合并两部分贡献，得到起终点直线上的 K 个三维基准点。
base = fromStart + fromGoal;

% 计算起点到终点在水平平面中的方向向量。
horizontalDirection = goalPoint(1:2) - startPoint(1:2);

% 计算水平任务距离，并用 eps 防止起终点水平重合时除零。
horizontalLength = max(norm(horizontalDirection), eps);

% 构造与水平任务方向正交的单位法向量，用于横向通道扰动。
normalDirection = [-horizontalDirection(2), horizontalDirection(1)] / horizontalLength;

% 以地图较短边作为横向扰动的统一物理尺度。
mapScale = min(diff(env.xLim), diff(env.yLim));

% 为 K 个内部点生成高斯随机扰动样本。
noise = randn(K, 1);

% 当内部点不少于三个时，对噪声做局部平滑，减少锯齿式初始化。
if K >= 3
    % 移动平均保持向量长度不变，只改变随机扰动的局部相关性。
    noise = movmean(noise, 3, 'Endpoints', 'shrink');
end

% 取得噪声绝对值最大值，并至少取 1，避免小样本噪声被异常放大。
noiseScale = max(max(abs(noise)), 1);

% 将无量纲噪声换算为受配置控制的物理横向位移。
lateral = cfg.initialization.globalLateralScale * mapScale * noise / noiseScale;

% 显式把每个标量横向位移乘以二维单位法向量，得到 K×2 位移矩阵。
lateralOffset = bsxfun(@times, lateral, normalDirection);

% 将横向位移叠加到直线基准点的水平坐标上。
xy = base(:, 1:2) + lateralOffset;

% 把所有 x 坐标限制在地图水平范围内，避免初始化点离开 DEM。
xy(:, 1) = min(max(xy(:, 1), env.xLim(1)), env.xLim(2));

% 把所有 y 坐标限制在地图水平范围内，避免初始化点离开 DEM。
xy(:, 2) = min(max(xy(:, 2), env.yLim(1)), env.yLim(2));

% 查询每个水平控制点位置的地形高度。
terrainAtPoint = terrain_height(env, xy(:, 1), xy(:, 2));

% 对插值失败的点使用环境最低高度作为显式防御值。
terrainAtPoint(~isfinite(terrainAtPoint)) = env.zLim(1);

% 读取初始化高度随机裕度的下限与上限。
altitudeMargin = cfg.initialization.globalAltitudeMargin;

% 为每个内部控制点生成位于给定区间内的额外高度裕度。
randomMargin = altitudeMargin(1) + ...
    (altitudeMargin(2) - altitudeMargin(1)) * rand(K, 1);

% 在地形高度之上叠加硬净空和随机裕度，得到初始高度序列。
zHeight = terrainAtPoint + cfg.constraint.clearance + randomMargin;

% 当内部点不少于三个时，平滑高度序列以减少初始急剧爬升。
if K >= 3
    % 移动平均不会改变高度向量长度。
    zHeight = movmean(zHeight, 3, 'Endpoints', 'shrink');
end

% 将高度限制在环境允许的最低和最高飞行高度范围内。
zHeight = min(max(zHeight, env.zLim(1)), env.zLim(2));

% 将固定起点、K 个内部三维点和固定终点组成完整控制点矩阵。
controlPoints = [env.start; xy, zHeight; env.goal];

% 把完整控制点矩阵中的 K 个内部点编码为归一化决策向量。
z = encode_control_points(controlPoints, cfg, problem.physicalLB, problem.physicalUB);

% 通过镜像反射统一处理可能出现的微小数值越界。
z = reflect_bounds(z, 0, 1);
end
