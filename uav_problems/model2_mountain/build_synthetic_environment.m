function env = build_synthetic_environment(cfg, scenarioId, seed)
%BUILD_SYNTHETIC_ENVIRONMENT 构造可复现的复杂山地测试环境。
%
% 本函数用于代码调试和合成场景实验，不冒充真实 DEM。正式真实地形实验
% 应使用 load_dem_environment，并保存数据来源、裁剪范围、投影和分辨率。
%
% 输入：
%   cfg        - default_config 返回的配置
%   scenarioId - 1~6，对应从基础到综合动态场景
%   seed       - 场景随机种子。相同 seed 保证地形与障碍完全一致。
%
% 输出 env：
%   xLim/yLim/zLim、terrain、start/goal、staticObstacles、
%   dynamicObstacles、wind、scenarioName 等。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin < 2 || isempty(scenarioId), scenarioId = 3; end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin < 3 || isempty(seed), seed = 1000 + scenarioId; end
% [逐行说明] 计算或更新 `state`，供后续算法、评价或日志步骤使用。
state = rng;
% [逐行说明] 计算或更新 `cleanup`，供后续算法、评价或日志步骤使用。
cleanup = onCleanup(@() rng(state)); %#ok<NASGU>
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
rng(seed, 'twister');

% [逐行说明] 计算或更新 `env`，供后续算法、评价或日志步骤使用。
env = struct();
% [逐行说明] 计算或更新 `env.id`，供后续算法、评价或日志步骤使用。
env.id = sprintf('S%d', scenarioId);
% [逐行说明] 计算或更新 `env.seed`，供后续算法、评价或日志步骤使用。
env.seed = seed;
% [逐行说明] 计算或更新 `env.xLim`，供后续算法、评价或日志步骤使用。
env.xLim = [0, 1200];
% [逐行说明] 计算或更新 `env.yLim`，供后续算法、评价或日志步骤使用。
env.yLim = [0, 1200];
% [逐行说明] 计算或更新 `env.zLim`，供后续算法、评价或日志步骤使用。
env.zLim = [0, 500];

% 生成规则网格。评价器使用原始网格插值，避免搜索引导平滑掩盖山脊。
nx = 161; ny = 161;
% [逐行说明] 计算或更新 `x`，供后续算法、评价或日志步骤使用。
x = linspace(env.xLim(1), env.xLim(2), nx);
% [逐行说明] 计算或更新 `y`，供后续算法、评价或日志步骤使用。
y = linspace(env.yLim(1), env.yLim(2), ny);
% [逐行说明] 计算或更新 `[X, Y]`，供后续算法、评价或日志步骤使用。
[X, Y] = meshgrid(x, y);

% 基础起伏：缓慢波动 + 多个高斯山体 + 山脊。
Z = 25 + 12*sin(X/180).*cos(Y/210) + 8*cos((X+Y)/260);
% [逐行说明] 计算或更新 `peaks`，供后续算法、评价或日志步骤使用。
peaks = [ ...
    330 360 145 120 160; ...
    720 610 210 140 180; ...
    980 360 150 110 130; ...
    500 950 170 170 120; ...
    930 930 130 130 150];
% [逐行说明] 开始按给定索引范围逐项执行循环。
for k = 1:size(peaks,1)
    % [逐行说明] 计算或更新 `cx`，供后续算法、评价或日志步骤使用。
    cx = peaks(k,1); cy = peaks(k,2); amp = peaks(k,3);
    % [逐行说明] 计算或更新 `sx`，供后续算法、评价或日志步骤使用。
    sx = peaks(k,4); sy = peaks(k,5);
    % [逐行说明] 计算或更新 `Z`，供后续算法、评价或日志步骤使用。
    Z = Z + amp * exp(-0.5*((X-cx).^2/sx^2 + (Y-cy).^2/sy^2));
end

% 场景难度逐步增加。S2/S3 加入山脊以形成多通道和狭窄山口。
if scenarioId >= 2
    % [逐行说明] 计算或更新 `ridge`，供后续算法、评价或日志步骤使用。
    ridge = 120 * exp(-0.5*((X-610)/55).^2) .* ...
        (0.35 + 0.65*exp(-0.5*((Y-600)/420).^2));
    % 在 y≈420 和 y≈850 附近挖出两个山口，形成不同拓扑通道。
    gates = 1 - 0.75*exp(-0.5*((Y-420)/70).^2) - 0.65*exp(-0.5*((Y-850)/85).^2);
    % [逐行说明] 计算或更新 `gates`，供后续算法、评价或日志步骤使用。
    gates = max(gates, 0.15);
    % [逐行说明] 计算或更新 `Z`，供后续算法、评价或日志步骤使用。
    Z = Z + ridge .* gates;
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if scenarioId >= 3
    % [逐行说明] 计算或更新 `narrowRidge`，供后续算法、评价或日志步骤使用。
    narrowRidge = 95 * exp(-0.5*((Y-670)/45).^2) .* exp(-0.5*((X-760)/300).^2);
    % [逐行说明] 计算或更新 `narrowGate`，供后续算法、评价或日志步骤使用。
    narrowGate = 1 - 0.82*exp(-0.5*((X-820)/55).^2);
    % [逐行说明] 计算或更新 `Z`，供后续算法、评价或日志步骤使用。
    Z = Z + narrowRidge .* max(narrowGate, 0.12);
end

% 小尺度纹理只用于增加地形梯度，不代表真实测量噪声。
Z = Z + 2.5*sin(X/37).*sin(Y/43);
% [逐行说明] 计算或更新 `Z`，供后续算法、评价或日志步骤使用。
Z = max(Z, 0);

% [逐行说明] 计算或更新 `env.terrain`，供后续算法、评价或日志步骤使用。
env.terrain = struct();
% [逐行说明] 计算或更新 `env.terrain.x`，供后续算法、评价或日志步骤使用。
env.terrain.x = x;
% [逐行说明] 计算或更新 `env.terrain.y`，供后续算法、评价或日志步骤使用。
env.terrain.y = y;
% [逐行说明] 计算或更新 `env.terrain.Z`，供后续算法、评价或日志步骤使用。
env.terrain.Z = Z;
% [逐行说明] 计算或更新 `env.terrain.source`，供后续算法、评价或日志步骤使用。
env.terrain.source = 'synthetic';
% [逐行说明] 计算或更新 `env.terrain.description`，供后续算法、评价或日志步骤使用。
env.terrain.description = 'Analytic multi-peak synthetic mountainous terrain';

% 起终点高度均保证高于局部地形净空。
startXY = [70, 110];
% [逐行说明] 计算或更新 `goalXY`，供后续算法、评价或日志步骤使用。
goalXY = [1130, 1080];
% [逐行说明] 计算或更新 `startH`，供后续算法、评价或日志步骤使用。
startH = terrain_height(env, startXY(1), startXY(2));
% [逐行说明] 计算或更新 `goalH`，供后续算法、评价或日志步骤使用。
goalH = terrain_height(env, goalXY(1), goalXY(2));
% [逐行说明] 计算或更新 `env.start`，供后续算法、评价或日志步骤使用。
env.start = [startXY, startH + cfg.constraint.clearance + 25];
% [逐行说明] 计算或更新 `env.goal`，供后续算法、评价或日志步骤使用。
env.goal = [goalXY, goalH + cfg.constraint.clearance + 25];

% 静态障碍仅从 S1 的稀疏障碍逐步增加。障碍为有限高度圆柱。
obs = struct('type', {}, 'center', {}, 'radius', {}, 'zMin', {}, 'zMax', {}, 'name', {});
% [逐行说明] 计算或更新 `obs(end+1)`，供后续算法、评价或日志步骤使用。
obs(end+1) = make_cylinder([420, 550], 42, 0, 310, 'tower_A'); %#ok<AGROW>
% [逐行说明] 计算或更新 `obs(end+1)`，供后续算法、评价或日志步骤使用。
obs(end+1) = make_cylinder([860, 780], 48, 0, 360, 'no_fly_B'); %#ok<AGROW>
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if scenarioId >= 2
    % [逐行说明] 计算或更新 `obs(end+1)`，供后续算法、评价或日志步骤使用。
    obs(end+1) = make_cylinder([585, 420], 28, 0, 330, 'gate_obstacle_C'); %#ok<AGROW>
    % [逐行说明] 计算或更新 `obs(end+1)`，供后续算法、评价或日志步骤使用。
    obs(end+1) = make_cylinder([650, 850], 36, 0, 350, 'gate_obstacle_D'); %#ok<AGROW>
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if scenarioId >= 4
    % [逐行说明] 计算或更新 `obs(end+1)`，供后续算法、评价或日志步骤使用。
    obs(end+1) = make_cylinder([240, 780], 55, 0, 280, 'restricted_E'); %#ok<AGROW>
    % [逐行说明] 计算或更新 `obs(end+1)`，供后续算法、评价或日志步骤使用。
    obs(end+1) = make_cylinder([1020, 560], 40, 0, 390, 'restricted_F'); %#ok<AGROW>
end
% [逐行说明] 计算或更新 `env.staticObstacles`，供后续算法、评价或日志步骤使用。
env.staticObstacles = obs;

% 风场按场景等级配置。
if scenarioId < 5
    % [逐行说明] 计算或更新 `env.wind`，供后续算法、评价或日志步骤使用。
    env.wind = struct('type', 'constant', 'constant', [1.5, -0.5, 0.0]);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `env.wind`，供后续算法、评价或日志步骤使用。
    env.wind = struct();
    % [逐行说明] 计算或更新 `env.wind.type`，供后续算法、评价或日志步骤使用。
    env.wind.type = 'terrain_composite';
    % [逐行说明] 计算或更新 `env.wind.base`，供后续算法、评价或日志步骤使用。
    env.wind.base = [2.5, 0.5, 0.0];
    % [逐行说明] 计算或更新 `env.wind.shear`，供后续算法、评价或日志步骤使用。
    env.wind.shear = [0.004, -0.002, 0.0];
    % [逐行说明] 计算或更新 `env.wind.vortexCenter`，供后续算法、评价或日志步骤使用。
    env.wind.vortexCenter = [650, 620];
    % [逐行说明] 计算或更新 `env.wind.vortexStrength`，供后续算法、评价或日志步骤使用。
    env.wind.vortexStrength = 6.0;
    % [逐行说明] 计算或更新 `env.wind.verticalScale`，供后续算法、评价或日志步骤使用。
    env.wind.verticalScale = 1.5;
end

% 动态障碍只在 S6 启用。位置和速度均由场景固定，不随优化器随机流变化。
dyn = struct('p0', {}, 'velocity', {}, 'radius', {}, 'sigma0', {}, 'sigmaRate', {}, 'name', {});
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if scenarioId >= 6
    % [逐行说明] 计算或更新 `dyn(end+1)`，供后续算法、评价或日志步骤使用。
    dyn(end+1) = make_dynamic([520, 260, 210], [0.5, 5.0, 0.0], 8, 2.0, 0.03, 'other_UAV_1'); %#ok<AGROW>
    % [逐行说明] 计算或更新 `dyn(end+1)`，供后续算法、评价或日志步骤使用。
    dyn(end+1) = make_dynamic([900, 1050, 260], [-4.2, -1.2, 0.0], 10, 3.0, 0.04, 'bird_group_2'); %#ok<AGROW>
    % [逐行说明] 计算或更新 `dyn(end+1)`，供后续算法、评价或日志步骤使用。
    dyn(end+1) = make_dynamic([300, 900, 180], [3.0, -3.8, 0.2], 7, 2.5, 0.05, 'other_UAV_3'); %#ok<AGROW>
end
% [逐行说明] 计算或更新 `env.dynamicObstacles`，供后续算法、评价或日志步骤使用。
env.dynamicObstacles = dyn;

% [逐行说明] 计算或更新 `names`，供后续算法、评价或日志步骤使用。
names = {'基础平缓', '多通道', '狭窄山口', '复杂静态', '空间风场', '综合动态'};
% [逐行说明] 计算或更新 `env.scenarioName`，供后续算法、评价或日志步骤使用。
env.scenarioName = names{max(1,min(6,scenarioId))};
% [逐行说明] 计算或更新 `env.meta`，供后续算法、评价或日志步骤使用。
env.meta = struct('generator', mfilename, 'seed', seed, 'isRealDEM', false);
end

function o = make_cylinder(center, radius, zMin, zMax, name)
% [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
o = struct('type', 'cylinder', 'center', center, 'radius', radius, ...
    'zMin', zMin, 'zMax', zMax, 'name', name);
end

function o = make_dynamic(p0, velocity, radius, sigma0, sigmaRate, name)
% [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
o = struct('p0', p0, 'velocity', velocity, 'radius', radius, ...
    'sigma0', sigma0, 'sigmaRate', sigmaRate, 'name', name);
end
