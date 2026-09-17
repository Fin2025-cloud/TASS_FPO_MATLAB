function env = build_multichannel_environment(cfg,seed)
%BUILD_MULTICHANNEL_ENVIRONMENT 构造具有“不可越顶山脊—多山口”的 S2 场景。
%
% 设计目的
% -------------------------------------------------------------------------
% 旧版 S2 只是在普通合成山地上叠加较低山脊。由于路径搜索高度上限较高，
% 无人机能够直接从山脊上方飞过，因此图中虽然出现起伏，却没有形成真正的
% 多拓扑通道。本函数把 S2 重构为两个横贯地图的高山脊屏障，并在每个屏障
% 上保留三个错位山口。屏障峰顶在计入最小离地净空后高于允许飞行上限，
% 因而可行路径必须选择山口，而不是简单抬高 Z 坐标越顶。
%
% 数据真实性说明
% -------------------------------------------------------------------------
% S2 仍是机制分析用的合成环境，不冒充真实 DEM。全部数学参数均固定并写在
% 本文件中；seed 仅作为场景元数据保留，当前地形本身不使用随机扰动。
%
% 输出结构与 build_synthetic_environment / load_dem_environment 完全一致，
% 因而不需要修改优化器、目标函数、约束函数或比较算法。

if nargin < 2 || isempty(seed)
    seed = 102000;
end

%% 1. 冻结地图范围与飞行高度范围
% 地图采用米制局部笛卡尔坐标。Z 上限设置为 330 m；山脊最高处约 315 m，
% 加上 30 m 默认净空后超过 Z 上限，因此山脊主体不可越顶。
env = struct();
env.id = 'S2';
env.seed = seed;
env.xLim = [0,1400];
env.yLim = [0,1000];
env.zLim = [0,330];

%% 2. 构造规则地形栅格
% 5 m 网格便于清楚表达约 100 m 宽的山口。评价阶段仍由统一的线性插值器
% 查询，不会因为本场景是合成地形而使用不同的评价公式。
x = linspace(env.xLim(1),env.xLim(2),281);
y = linspace(env.yLim(1),env.yLim(2),201);
[X,Y] = meshgrid(x,y);

% 低幅基础起伏只用于避免完全平坦的谷底。
Z = 32 ...
    + 6*sin(X/150).*cos(Y/130) ...
    + 4*cos((X+0.6*Y)/230);

% 第一条屏障山脊：三个山口中心位于 y=180/500/820 m。
Z = Z + ridge_with_gates(X,Y,460,275,[180 500 820],42,52);

% 第二条屏障山脊：山口位置与第一条错开，路径需要在两条山脊之间转向，
% 从而形成多条具有不同长度、爬升和曲率代价的拓扑通道。
Z = Z + ridge_with_gates(X,Y,940,275,[290 610 900],42,52);

% 两条山脊之间增加两个低矮长丘，用于区分不同通道的地形代价，但其高度
% 不会封闭山口，也不会替代山脊作为主要可行域边界。
Z = Z + 55*exp(-0.5*(((X-700)/170).^2+((Y-350)/110).^2));
Z = Z + 48*exp(-0.5*(((X-720)/150).^2+((Y-760)/100).^2));
Z = max(Z,0);

env.terrain = struct();
env.terrain.x = x;
env.terrain.y = y;
env.terrain.Z = Z;
env.terrain.source = 'synthetic_multichannel_v1.1.1';
env.terrain.description = [ ...
    'Deterministic two-barrier synthetic terrain with three offset gates ' ...
    'per barrier; ridge tops cannot be overflown under the frozen z ceiling'];

%% 3. 设置起终点
% 起点和终点位于两条屏障的相对两侧，且水平投影接近地图中线。直接连线会
% 同时撞上两条山脊，因此优化器必须在多个山口组合之间做选择。
startXY = [70,500];
goalXY = [1330,500];
startTerrain = terrain_height(env,startXY(1),startXY(2));
goalTerrain = terrain_height(env,goalXY(1),goalXY(2));
additionalAltitude = 15;
env.start = [startXY,startTerrain+cfg.constraint.clearance+additionalAltitude];
env.goal = [goalXY,goalTerrain+cfg.constraint.clearance+additionalAltitude];

%% 4. 场景附加层
% S2 的研究变量是地形拓扑通道，因此不再叠加有限高度圆柱。这样论文图中
% 可直接观察算法选择的是哪个山口，而不会把通道效应与障碍物效应混在一起。
env.staticObstacles = struct([]);
env.dynamicObstacles = struct([]);
env.wind = struct('type','constant','constant',[0 0 0]);
env.scenarioName = '合成双山脊三山口多通道场景';

%% 5. 保存可审计的场景元数据
env.meta = struct();
env.meta.generator = mfilename;
env.meta.seed = seed;
env.meta.isRealDEM = false;
env.meta.topology = 'two transverse barriers with three offset gates each';
env.meta.barrierX = [460 940];
env.meta.gateYBarrier1 = [180 500 820];
env.meta.gateYBarrier2 = [290 610 900];
env.meta.zCeiling = env.zLim(2);
env.meta.minimumClearance = cfg.constraint.clearance;
env.meta.maximumTerrain = max(Z(:));
env.meta.ridgeOverflightFeasible = ...
    (env.meta.maximumTerrain+cfg.constraint.clearance <= env.zLim(2));
end

function contribution = ridge_with_gates(X,Y,xCenter,amplitude,gateCenters, ...
    ridgeSigma,gateSigma)
%RIDGE_WITH_GATES 生成横贯 y 方向的高山脊，并在指定位置挖出平滑山口。
%
% 高斯项控制山脊在 x 方向的宽度；gateFactor 在每个 gateCenters 附近下降。
% 下限 0.055 防止数值上形成负山脊，同时保留清晰、连续的低山口。
ridge = amplitude*exp(-0.5*((X-xCenter)/ridgeSigma).^2);
gateFactor = ones(size(Y));
for k = 1:numel(gateCenters)
    gateFactor = gateFactor ...
        - 0.94*exp(-0.5*((Y-gateCenters(k))/gateSigma).^2);
end
gateFactor = max(gateFactor,0.055);
contribution = ridge.*gateFactor;
end
