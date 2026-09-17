function result = evaluate_path(z, env, cfg, physicalLB, physicalUB)
%EVALUATE_PATH 统一三维 UAV 路径评价器。
%
% 核心职责
% -------------------------------------------------------------------------
% 本函数把一个归一化决策向量依次转换为：
%   1) 夹持 B 样条三维轨迹；
%   2) 自适应加密后的轨迹采样点；
%   3) 时间、地速、空速、曲率、加速度等运动学量；
%   4) 地形、静态障碍、动态障碍和平台能力约束违反；
%   5) 长度、能耗、风险、平滑度和飞行时间目标；
%   6) 无量纲总违反度 CV 与综合目标 F。
%
% 实验真实性约束
% -------------------------------------------------------------------------
% 1) 所有算法必须调用同一份 evaluate_path，不能在某个算法内部复制并修改；
% 2) 每次调用本函数都应由外层优化器计为一次完整函数评价 FE；
% 3) 本函数不调用随机数，因此同一 z、env、cfg 必须得到完全相同的结果；
% 4) 本函数不修改 env、cfg、物理边界或算法种群；
% 5) 输入越界不会在此处被静默修复，而会形成 boundary 违反；
% 6) 各约束先按物理单位计算，再使用预先固定尺度无量纲化。
%
% 数值兼容性
% -------------------------------------------------------------------------
% 关键矩阵运算使用 bsxfun 或显式列向量，避免行列方向或隐式扩展引起的
% MATLAB:dimagree。该修改只消除实现歧义，不改变数学模型和实验定义。

% 把输入统一转换为双精度行向量，确保决策变量排列稳定。
z = double(z(:)');

% 预先创建返回结构，便于异常分支直接返回统一格式。
result = struct();

% 检查决策变量是否全部有限，以及维数是否严格等于 3K。
if any(~isfinite(z)) || numel(z) ~= 3 * cfg.path.K
    % 对非法输入返回确定性的极差结果，而不是传播 NaN 破坏种群排序。
    result = invalid_result('nonfinite_or_dimension');

    % 结束本次评价。
    return;
end

% 计算归一化决策变量超出 [0,1] 的最大幅度，作为边界原始违反量。
boundaryViolation = max([max(-z), max(z - 1), 0]);

% 使用 try/catch 隔离解码或采样异常，保证单个坏候选不会终止整次实验。
try
    % 将归一化变量解码为夹持 B 样条控制点和初始轨迹采样。
    path = decode_bspline_path(z, env, cfg, physicalLB, physicalUB);

    % 在长线段、低净空和高转角位置增加采样点，提高约束检测可靠性。
    path = adaptive_refine_path(path, env, cfg);
catch ME
    % 用 MATLAB 异常标识记录解码失败原因，便于正式实验审计。
    result = invalid_result(['decode_error:' ME.identifier]);

    % 结束本次评价。
    return;
end

% 提取自适应采样后的三维轨迹点，尺寸应为 M_actual×3。
P = double(path.P);

% 检查轨迹采样矩阵是否包含 NaN 或 Inf。
if any(~isfinite(P(:)))
    % 非有限轨迹返回确定性的极差结果。
    result = invalid_result('nonfinite_path');

    % 结束本次评价。
    return;
end

% 检查轨迹至少包含两个点，否则无法形成线段和飞行时间。
if size(P, 1) < 2 || size(P, 2) ~= 3
    % 轨迹形状非法时返回统一错误结果。
    result = invalid_result('invalid_path_shape');

    % 结束本次评价。
    return;
end

%% 一、线段几何、时间、地速和空速

% 计算相邻轨迹采样点的三维位移向量，每行对应一条线段。
dP = diff(P, 1, 1);

% 计算每条轨迹线段的欧氏长度，并强制转换为列向量。
ds = vecnorm(dP, 2, 2);
ds = ds(:);
% Near-stationary sampled segments make fixed-speed directions and discrete
% curvature numerically undefined. Reject rather than report spurious safety.
minResolvedLength=1e-9*max(norm(env.goal-env.start),1);
if any(ds<=minResolvedLength)
    result=invalid_result('unresolved_stationary_segment');
    return;
end

% 为归一化方向向量构造不小于 eps 的线段长度分母。
safeDs = max(ds, eps);

% 用显式按行除法计算每条线段的单位方向，避免 N×3 与 N×1 维度歧义。
direction = bsxfun(@rdivide, dP, safeDs);

% 根据固定地速模型计算每条线段的飞行时间。
deltaT = ds / cfg.uav.groundSpeed;

% 累加线段时间，得到每个轨迹采样点相对起飞时刻的到达时间。
time = [0; cumsum(deltaT)];

% 将单位线段方向乘以固定地速，得到每条线段的三维地速向量。
vg = cfg.uav.groundSpeed .* direction;

% 计算每条轨迹线段的空间中点，用于查询该段代表性风速。
midP = 0.5 .* (P(1:end-1, :) + P(2:end, :));

% 计算每条线段起止时刻的中点，用于时变风场查询接口。
midT = 0.5 .* (time(1:end-1) + time(2:end));

% 查询各线段中点处的三维风速向量。
W = wind_velocity(env, midP, midT);

% 检查风场输出是否与轨迹线段数量一致且每行包含三个分量。
if ~isequal(size(W), size(vg))
    % 风场尺寸错误会直接破坏空速计算，因此返回明确错误结果。
    result = invalid_result('wind_dimension_mismatch');

    % 结束本次评价。
    return;
end

% 根据 v_air = v_ground - W 计算每条线段的三维空速向量。
vAir = vg - W;

% 计算每条线段的空速标量。
airSpeed = vecnorm(vAir, 2, 2);
airSpeed = airSpeed(:);

%% 二、地形净空约束

% 在所有轨迹采样点的水平位置查询 DEM 地形高度。
terrainH = terrain_height(env, P(:, 1), P(:, 2));

% 强制地形高度为列向量，消除 interp2 对输入形状的继承差异。
terrainH = terrainH(:);

% 标记超出 DEM 范围或插值失败的轨迹点。
outside = ~isfinite(terrainH);

% 若存在地图外点，为这些点构造必然违反净空的人工地形高度。
if any(outside)
    % 使用对应轨迹高度加净空再加 1 m，确保违反量大于零。
    terrainH(outside) = P(outside, 3) + cfg.constraint.clearance + 1;
end

% 计算每个轨迹采样点相对地形表面的实际垂直净空。
clearance = P(:, 3) - terrainH;

% 计算每个点低于最小净空要求的缺口。
terrainDeficit = max(0, cfg.constraint.clearance - clearance);

% 对地图外点至少赋予一个完整净空尺度的违反，避免被误判为轻微越界。
if any(outside)
    % 将地图外点的净空违反下界设为配置净空值。
    terrainDeficit(outside) = max(terrainDeficit(outside), cfg.constraint.clearance);
end

% 取得整条路径最严重的地形净空违反量及其轨迹采样点位置。
[maxTerrainDeficit, worstTerrainIdx] = max(terrainDeficit);

%% 三、静态与动态障碍约束

% 对所有轨迹线段和有限高度静态障碍执行连续最小距离检查。
staticInfo = static_obstacle_check(P, env, cfg);

% 在每个时间区间内对 UAV 与动态障碍的相对线性运动执行连续碰撞检查。
dynamicInfo = dynamic_obstacle_check(P, time, env, cfg);

%% 四、爬升角、转角、曲率、加速度和空速上限

% 计算每条线段在水平平面中的长度。
horizontalLength = vecnorm(dP(:, 1:2), 2, 2);
horizontalLength = horizontalLength(:);

% 用 eps 保护接近竖直线段的分母，同时由 atan2 保留正确象限。
safeHorizontalLength = max(horizontalLength, eps);

% 计算每条线段的有符号爬升/下降角。
climbAngle = atan2(dP(:, 3), safeHorizontalLength);
climbAngle = climbAngle(:);

% 计算超过最大允许爬升/下降角的部分。
climbExcess = max(0, abs(climbAngle) - cfg.uav.maxClimbAngle);

% 为每个内部轨迹点预分配转角向量，长度为采样点数减二。
turnAngle = zeros(max(size(P, 1) - 2, 0), 1);

% 为每个内部轨迹点预分配离散曲率向量。
curvature = zeros(size(turnAngle));

% 只有至少三个轨迹点时才能计算相邻线段夹角和三点外接曲率。
if size(P, 1) >= 3
    % 计算每个内部点之前的线段向量。
    a = P(2:end-1, :) - P(1:end-2, :);

    % 计算每个内部点之后的线段向量。
    b = P(3:end, :) - P(2:end-1, :);

    % 计算跨越两个相邻线段的弦向量。
    c = P(3:end, :) - P(1:end-2, :);

    % 计算相邻线段夹角余弦的分子，即逐行点积。
    cosineNumerator = sum(a .* b, 2);

    % 计算相邻线段长度乘积，并用 eps 防止退化点除零。
    cosineDenominator = vecnorm(a, 2, 2) .* vecnorm(b, 2, 2) + eps;

    % 计算夹角余弦。
    cosineAngle = cosineNumerator ./ cosineDenominator;

    % 将数值误差限制在 [-1,1] 后反余弦，得到转角。
    turnAngle = acos(max(-1, min(1, cosineAngle)));

    % 通过叉积模长计算由 a、b 张成三角形的两倍面积。
    twiceArea = vecnorm(cross(a, b, 2), 2, 2);

    % 构造离散曲率公式的三个边长乘积。
    curvatureDenominator = vecnorm(a, 2, 2) .* ...
        vecnorm(b, 2, 2) .* vecnorm(c, 2, 2) + eps;

    % 使用 κ = 2|a×b|/(|a||b||c|) 计算三点离散曲率。
    curvature = 2 .* twiceArea ./ curvatureDenominator;
end

% 计算各内部轨迹点超过最大允许曲率的部分。
curvatureExcess = max(0, curvature - cfg.uav.maxCurvature);

% 为相邻地速变化预分配近似加速度向量。
acceleration = zeros(max(size(vg, 1) - 1, 0), 1);

% 至少有两条轨迹线段时才能计算线段间速度变化。
if size(vg, 1) >= 2
    % 计算相邻线段地速向量变化的模长。
    velocityChange = vecnorm(diff(vg, 1, 1), 2, 2);

    % 使用前一线段持续时间作为离散加速度时间尺度，并用 eps 防止除零。
    accelerationTime = max(deltaT(1:end-1), eps);

    % 计算近似加速度标量。
    acceleration = velocityChange ./ accelerationTime;
end

% 计算各位置超过平台最大加速度的部分。
accelerationExcess = max(0, acceleration - cfg.uav.maxAcceleration);

% 计算各线段超过平台最大空速的部分。
airSpeedExcess = max(0, airSpeed - cfg.uav.maxAirSpeed);

%% 五、基础性能指标与能耗

% 创建统一指标结构，供能耗模型和结果记录共同使用。
metrics = struct();

% 保存整条路径的三维弧长。
metrics.length = sum(ds);

% 保存每条线段的垂直高度变化。
metrics.deltaZ = dP(:, 3);

% 保存每条线段的飞行时间。
metrics.deltaT = deltaT;

% 保存内部轨迹点转角。
metrics.turnAngle = turnAngle;

% 保存内部轨迹点离散曲率。
metrics.curvature = curvature;

% 保存每条线段空速标量。
metrics.airSpeed = airSpeed;

% 保存每条线段空速的水平分量模长。
metrics.horizontalAirSpeed = vecnorm(vAir(:, 1:2), 2, 2);

% 保存每条线段空速的垂直分量。
metrics.verticalAirSpeed = vAir(:, 3);

% 保存离散近似加速度。
metrics.acceleration = acceleration;

% 保存从起点飞至终点的总飞行时间。
metrics.time = time(end);

% 根据配置选择开发级 A 模型或旋翼解析 B 模型。
if strcmpi(cfg.energy.model, 'B')
    % 使用旋翼解析功率模型计算总能耗和逐段功率。
    [energy, power] = energy_model_B(metrics, cfg);
else
    % 使用可解释的开发级组合模型计算总能耗。
    energy = energy_model_A(metrics, cfg);

    % A 模型不输出逐段功率，因此使用空数组占位。
    power = [];
end

% 计算硬约束之外的连续安全风险积分。
risk = compute_risk(P, time, clearance, env, cfg);

% 取得与曲率向量一一对应的后继线段长度，保持原方案定义不变。
curvatureArcWeight = max(ds(2:end), eps);

% 计算转角平方和与曲率平方弧长加权和，作为轨迹平滑度代价。
% v2: dimensionless curvature energy, without a sample-count-dependent angle sum.
referenceArc = norm(env.goal-env.start);
smoothness = referenceArc * sum((curvature .^ 2) .* curvatureArcWeight);

%% 六、预先固定的目标归一化与综合目标

% 读取并补齐实验开始前冻结的目标归一化基准。
%
% 重要说明：MATLAB 采用值传递语义。make_problem(env,cfg) 在其内部补齐
% referenceLength 和 referenceTime 后，调用者原来的 cfg 并不会被原地修改。
% 因此，若测试脚本或用户直接调用 evaluate_path(z,env,cfg,...) 且 cfg 中
% 这两个字段仍为空，直接执行“标量 / []”会触发 MATLAB:dimagree。
%
% resolve_objective_normalization 仅在参考值为空时，使用与 make_problem
% 完全相同的预定义规则补齐：
%   referenceLength = 起点到终点的三维直线距离；
%   referenceTime   = referenceLength / 固定地速。
% 对用户显式给出的非空参考值不会重估、调优或覆盖，因此不会改变正式
% 实验的目标定义，也不会利用当前候选路径或任何算法结果进行归一化。
normCfg = resolve_objective_normalization(cfg.objective.norm, env, cfg);

% 将路径长度除以参考长度，得到无量纲长度目标。
% referenceLength 已由辅助函数保证为有限、正的标量。
Lhat = metrics.length / normCfg.referenceLength;

% 将总能耗除以参考能耗，得到无量纲能耗目标。
Ehat = energy / normCfg.referenceEnergy;

% 将风险积分除以参考风险，得到无量纲风险目标。
Rhat = risk / normCfg.referenceRisk;

% 将平滑度代价除以参考平滑度，得到无量纲平滑目标。
Shat = smoothness / normCfg.referenceSmoothness;

% 将总飞行时间除以参考时间，得到无量纲时间目标。
That = metrics.time / normCfg.referenceTime;

% 读取长度、能耗、风险、平滑度和时间的固定权重。
w = cfg.objective.weights;

% 对五个无量纲子目标加权求和，得到待最小化综合目标 F。
F = w.length * Lhat + w.energy * Ehat + w.risk * Rhat + ...
    w.smoothness * Shat + w.time * That;

%% 七、硬约束原始违反量与无量纲总违反度

% 计算总能耗超过可用电池能量的部分。
energyExcess = max(0, energy - cfg.uav.batteryEnergy);

% 创建各类物理违反量结构。
raw = struct();

% 保存最严重地形净空不足，单位为米。
raw.terrain = maxTerrainDeficit;

% 保存最严重静态障碍安全距离不足，单位为米。
raw.static = staticInfo.maxDeficit;

% 保存最严重动态障碍安全距离不足，单位为米。
raw.dynamic = dynamicInfo.maxDeficit;

% 保存最大爬升角超限，单位为弧度。
raw.climb = max([climbExcess; 0]);

% 保存最大曲率超限，单位为 1/m。
raw.curvature = max([curvatureExcess; 0]);

% 保存最大空速超限，单位为 m/s。
raw.airSpeed = max([airSpeedExcess; 0]);

% 保存最大加速度超限，单位为 m/s^2。
raw.acceleration = max([accelerationExcess; 0]);

% 保存电池能量超限，单位为焦耳。
raw.energy = energyExcess;

% 将归一化边界超限与地图外标志合并为边界违反。
raw.boundary = max(boundaryViolation, double(any(outside)));

% 按预先固定的物理尺度和权重计算总无量纲违反度 CV。
[CV, normalizedViolation] = aggregate_violation(raw, cfg);

% 当 CV 不超过统一容差时，把路径判定为可行。
isFeasible = CV <= cfg.constraint.feasibilityTolerance;

%% 八、统一结果结构

% 保存综合目标值。
result.F = F;

% 保存总无量纲约束违反度。
result.CV = CV;

% 保存可行性逻辑标志。
result.isFeasible = isFeasible;

% 保存本次评价对应的归一化决策向量。
result.z = z;

% 保存各目标原始值及其无量纲值。
result.cost = struct('total', F, 'length', metrics.length, 'energy', energy, ...
    'risk', risk, 'smoothness', smoothness, 'time', metrics.time, ...
    'normalized', struct('length', Lhat, 'energy', Ehat, 'risk', Rhat, ...
    'smoothness', Shat, 'time', That));

% 保存本次评价实际使用的五个固定归一化参考值，便于正式实验审计。
% 该字段只记录已经确定的尺度，不参与任何后续搜索或参数更新。
result.objectiveNormalization = normCfg;

% 保存各类物理违反量、无量纲违反量及总违反度。
result.violation = struct('total', CV, 'raw', raw, ...
    'normalized', normalizedViolation, 'terrain', raw.terrain, ...
    'staticObstacle', raw.static, 'dynamicObstacle', raw.dynamic, ...
    'climb', raw.climb, 'curvature', raw.curvature, ...
    'airSpeed', raw.airSpeed, 'acceleration', raw.acceleration, ...
    'energy', raw.energy, 'boundary', raw.boundary);

% 保存完整解码路径结构。
result.path = path;

% 保存自适应采样后的三维轨迹点。
result.pathSamples = P;

% 保存每个轨迹采样点对应的 B 样条参数 u。
result.sampleU = path.u;

% 保存 B 样条基函数矩阵，供约束类型修复映射到控制点。
result.basisMatrix = path.basis;

% 保存包含固定起终点的完整控制点矩阵。
result.controlPoints = path.controlPoints;

% 保存每个轨迹采样点的累计到达时间。
result.arrivalTime = time;

% 保存运动学和几何基础指标。
result.metrics = metrics;

% 保存逐段旋翼功率；使用 A 模型时为空。
result.power = power;

% 保存整条路径的最小地形净空。
result.minClearance = min(clearance);

% 保存整条路径相对静态障碍表面的最小距离。
result.minStaticDistance = staticInfo.minDistance;

% 保存整条路径相对动态障碍表面的最小距离。
result.minDynamicDistance = dynamicInfo.minDistance;

% 保存最大绝对爬升/下降角。
result.maxClimbAngle = max([abs(climbAngle); 0]);

% 保存最大离散曲率。
result.maxCurvature = max([curvature; 0]);

% 保存最大空速。
result.maxAirSpeed = max([airSpeed; 0]);

% 保存最大近似加速度。
result.maxAcceleration = max([acceleration; 0]);

% 保存修复、审计和调试所需的中间信息。
result.details = struct('terrainWorstIndex', worstTerrainIdx, ...
    'terrainHeight', terrainH, 'clearance', clearance, ...
    'static', staticInfo, 'dynamic', dynamicInfo, ...
    'climbAngle', climbAngle, 'curvature', curvature, ...
    'acceleration', acceleration, 'wind', W);

% 标记本次评价已正常完成。
result.status = 'ok';
end


function normCfg = resolve_objective_normalization(normCfg, env, cfg)
%RESOLVE_OBJECTIVE_NORMALIZATION 补齐并验证五个目标归一化参考值。
%
% 为什么需要本函数
% -------------------------------------------------------------------------
% make_problem 会在其局部 cfg 副本中自动补齐 referenceLength 和
% referenceTime，并把补齐后的配置保存到 problem.cfg。由于 MATLAB 函数
% 参数按值传递，调用者原来的 cfg 不会同步改变。若用户绕过 problem.evaluate
% 而直接调用 evaluate_path，原 cfg 中的参考值可能仍为空。
%
% 为保证直接调用和 problem.evaluate 得到完全一致的数学定义，本函数只对
% “空参考值”应用与 make_problem 相同的确定性规则。它不读取当前路径长度、
% 当前能耗、种群统计或算法最优值，因此不会产生数据泄漏，也不会随候选解
% 自适应改变目标尺度。
%
% 输入
% -------------------------------------------------------------------------
% normCfg : cfg.objective.norm 的结构副本；
% env     : 当前环境，至少应包含 start 和 goal；
% cfg     : 完整配置，用于读取固定地速。
%
% 输出
% -------------------------------------------------------------------------
% normCfg : 五个参考值均为有限正标量的结构。

% 定义五个必须存在的参考值字段名，顺序与综合目标的五个分量一致。
requiredFields = {'referenceLength', 'referenceEnergy', 'referenceRisk', ...
    'referenceSmoothness', 'referenceTime'};

% 逐项检查字段是否存在，避免后续出现难以定位的“引用不存在字段”错误。
for fieldIndex = 1:numel(requiredFields)
    % 读取当前待检查的字段名。
    fieldName = requiredFields{fieldIndex};

    % 若配置缺少字段，立即抛出明确的配置错误，而不是静默猜测。
    if ~isfield(normCfg, fieldName)
        % 错误信息包含缺失字段名，便于用户直接定位 default_config 或配置覆盖。
        error('evaluate_path:MissingNormalizationReference', ...
            'cfg.objective.norm.%s is missing.', fieldName);
    end
end

% 将起点和终点统一转换为 3×1 列向量，消除行向量/列向量方向差异。
startPoint = double(env.start(:));
goalPoint = double(env.goal(:));

% 检查起点和终点都严格包含三个空间坐标分量。
if numel(startPoint) ~= 3 || numel(goalPoint) ~= 3
    % 环境坐标维数错误时，停止评价以防生成错误归一化尺度。
    error('evaluate_path:InvalidStartGoalDimension', ...
        'env.start and env.goal must each contain exactly three coordinates.');
end

% 计算起点到终点的三维直线距离；该值与 make_problem 中的规则一致。
straightLength = norm(goalPoint - startPoint);

% 若参考长度为空，则使用任务直线距离作为实验开始前可确定的固定基准。
if isempty(normCfg.referenceLength)
    % 起终点极端情况下重合时，以 eps 保证分母仍为正数。
    normCfg.referenceLength = max(straightLength, eps);
end

% 若参考时间为空，则使用直线距离除以固定地速作为固定时间基准。
if isempty(normCfg.referenceTime)
    % 首先读取固定地速，并显式转换为双精度标量。
    groundSpeed = double(cfg.uav.groundSpeed);

    % 配置验证理论上已保证地速为正，此处再次防止直接调用时出现非法除法。
    if ~isscalar(groundSpeed) || ~isfinite(groundSpeed) || groundSpeed <= 0
        % 抛出明确错误，禁止用错误地速静默改变目标时间尺度。
        error('evaluate_path:InvalidGroundSpeed', ...
            'cfg.uav.groundSpeed must be a finite positive scalar.');
    end

    % 使用与 make_problem 完全相同的直线飞行时间规则补齐参考时间。
    normCfg.referenceTime = max(straightLength / groundSpeed, eps);
end

% 逐项验证所有参考值均为有限、正的实标量。
for fieldIndex = 1:numel(requiredFields)
    % 读取当前参考值字段名。
    fieldName = requiredFields{fieldIndex};

    % 读取当前参考值。
    referenceValue = normCfg.(fieldName);

    % 禁止空值、向量、复数、NaN、Inf、零值和负值进入目标归一化。
    if isempty(referenceValue) || ~isnumeric(referenceValue) || ...
            ~isreal(referenceValue) || ~isscalar(referenceValue) || ...
            ~isfinite(referenceValue) || referenceValue <= 0
        % 抛出包含字段名的明确异常，防止矩阵右除或隐式维度错误。
        error('evaluate_path:InvalidNormalizationReference', ...
            'cfg.objective.norm.%s must be a finite positive real scalar.', ...
            fieldName);
    end

    % 统一转换为双精度，保证后续目标计算的数据类型一致。
    normCfg.(fieldName) = double(referenceValue);
end
end

function [CV, normalized] = aggregate_violation(raw, cfg)
%AGGREGATE_VIOLATION 将不同单位的物理违反量转换为无量纲总违反度。

% 取得 raw 结构中全部约束字段名称。
fields = fieldnames(raw);

% 将总违反度初始化为零。
CV = 0;

% 创建各类无量纲违反量的返回结构。
normalized = struct();

% 依次处理每一种硬约束。
for i = 1:numel(fields)
    % 读取当前约束字段名。
    fieldName = fields{i};

    % 读取该约束预先固定的物理归一化尺度。
    scale = cfg.constraint.scale.(fieldName);

    % 读取该约束在总违反度中的固定权重。
    weight = cfg.constraint.weight.(fieldName);

    % 把物理违反量除以尺度，并截断到 [0,1]，防止单类极端值完全主导 CV。
    normalizedValue = min(1, max(0, raw.(fieldName)) / (scale + eps));

    % 保存当前约束的无量纲违反量。
    normalized.(fieldName) = normalizedValue;

    % 将带权无量纲违反量累加到总 CV。
    CV = CV + weight * normalizedValue;
end
end

function r = invalid_result(status)
%INVALID_RESULT 为非法候选构造可被 Deb 规则稳定处理的统一结果。

% 创建结果结构。
r = struct();

% 使用远小于 realmax 的有限大数作为极差目标，避免后续运算溢出。
r.F = realmax / 100;

% 使用同样的有限大数作为极差约束违反度。
r.CV = realmax / 100;

% 非法候选必定不可行。
r.isFeasible = false;

% 为各原始目标填入 Inf，明确表示不可解释。
r.cost = struct('total', r.F, 'length', inf, 'energy', inf, ...
    'risk', inf, 'smoothness', inf, 'time', inf);

% 至少保留总违反度字段，保证外层 Deb 比较接口稳定。
r.violation = struct('total', r.CV);

% 保存异常状态字符串，便于日志审计。
r.status = status;

% 非法候选不保存有效决策向量。
r.z = [];

% 非法候选不保存轨迹采样。
r.pathSamples = [];

% 非法候选不保存控制点。
r.controlPoints = [];

% 非法候选没有有效中间细节。
r.details = struct();
end
