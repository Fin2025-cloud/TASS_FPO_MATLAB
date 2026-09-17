function cfg = default_config()
%DEFAULT_CONFIG 返回 TAAS-FPO 的完整默认配置。
%
% 设计原则
% -------------------------------------------------------------------------
% 1. 所有默认值仅作为“开发起点”，不是论文最终参数；
% 2. 正式实验前必须锁定配置，并在所有算法/场景中保持一致；
% 3. 任何会改变搜索预算、评价器或约束定义的参数都必须保存到结果文件；
% 4. 路径专用模块（TAI/CDR）在 CEC 实验中必须关闭。
%
% 建议调用方式：
%   cfg = default_config();
%   cfg.algorithm.N = 60;
%   cfg.algorithm.MaxFEs = 50000;
%
% 返回值 cfg 是纯结构体，便于保存为 MAT 文件和复现实验。

%% 1) 路径表示与采样
cfg.path.K = 12;                        % 内部 B 样条控制点数，维数 D=3K
% [逐行说明] 计算或更新 `cfg.path.M`，供后续算法、评价或日志步骤使用。
cfg.path.M = 400;                       % 初始均匀采样点数
% [逐行说明] 计算或更新 `cfg.path.splineDegree`，供后续算法、评价或日志步骤使用。
cfg.path.splineDegree = 3;              % 三次 B 样条
% [逐行说明] 计算或更新 `cfg.path.enableAdaptiveSampling`，供后续算法、评价或日志步骤使用。
cfg.path.enableAdaptiveSampling = true; % 是否对危险/高曲率区段加密采样
% [逐行说明] 计算或更新 `cfg.path.maxAdaptivePoints`，供后续算法、评价或日志步骤使用。
cfg.path.maxAdaptivePoints = 700;       % 单条轨迹最大采样点数
% [逐行说明] 计算或更新 `cfg.path.maxRefineRounds`，供后续算法、评价或日志步骤使用。
cfg.path.maxRefineRounds = 4;           % 自适应细分轮数上限
% [逐行说明] 计算或更新 `cfg.path.maxSegmentLength`，供后续算法、评价或日志步骤使用。
cfg.path.maxSegmentLength = 15.0;       % 采样线段最大长度[m]
% [逐行说明] 计算或更新 `cfg.path.curvatureRefineFactor`，供后续算法、评价或日志步骤使用。
cfg.path.curvatureRefineFactor = 0.70;  % 接近曲率上限时触发细分的比例
% [逐行说明] 计算或更新 `cfg.path.clearanceRefineFactor`，供后续算法、评价或日志步骤使用。
cfg.path.clearanceRefineFactor = 2.0;   % 净空低于 clearance*该系数时触发细分

%% 2) UAV 运动学和几何参数
cfg.uav.radius = 1.0;                   % UAV 球形包络半径[m]
% [逐行说明] 计算或更新 `cfg.uav.groundSpeed`，供后续算法、评价或日志步骤使用。
cfg.uav.groundSpeed = 12.0;             % 固定地速[m/s]
% [逐行说明] 计算或更新 `cfg.uav.maxAirSpeed`，供后续算法、评价或日志步骤使用。
cfg.uav.maxAirSpeed = 22.0;             % 最大允许空速[m/s]
% [逐行说明] 计算或更新 `cfg.uav.maxClimbAngle`，供后续算法、评价或日志步骤使用。
cfg.uav.maxClimbAngle = deg2rad(25);     % 最大爬升/下降角[rad]
% [逐行说明] 计算或更新 `cfg.uav.maxCurvature`，供后续算法、评价或日志步骤使用。
cfg.uav.maxCurvature = 0.08;           % 最大曲率[1/m]
% [逐行说明] 计算或更新 `cfg.uav.maxAcceleration`，供后续算法、评价或日志步骤使用。
cfg.uav.maxAcceleration = 3.0;          % 近似最大加速度[m/s^2]
% [逐行说明] 计算或更新 `cfg.uav.mass`，供后续算法、评价或日志步骤使用。
cfg.uav.mass = 6.0;                     % 质量[kg]
% [逐行说明] 计算或更新 `cfg.uav.gravity`，供后续算法、评价或日志步骤使用。
cfg.uav.gravity = 9.80665;               % 重力加速度[m/s^2]
% [逐行说明] 计算或更新 `cfg.uav.batteryEnergy`，供后续算法、评价或日志步骤使用。
cfg.uav.batteryEnergy = 1.6e6;          % 可用电池能量[J]，示例值

%% 3) 硬约束
cfg.constraint.clearance = 30.0;        % 地形最小净空[m]
% [逐行说明] 计算或更新 `cfg.constraint.staticSafety`，供后续算法、评价或日志步骤使用。
cfg.constraint.staticSafety = 8.0;      % 静态障碍额外安全距离[m]
% [逐行说明] 计算或更新 `cfg.constraint.dynamicSafety`，供后续算法、评价或日志步骤使用。
cfg.constraint.dynamicSafety = 10.0;    % 动态障碍额外安全距离[m]
% [逐行说明] 计算或更新 `cfg.constraint.robustEta`，供后续算法、评价或日志步骤使用。
cfg.constraint.robustEta = 2.0;         % 动态预测标准差膨胀系数
% [逐行说明] 计算或更新 `cfg.constraint.feasibilityTolerance`，供后续算法、评价或日志步骤使用。
cfg.constraint.feasibilityTolerance = 1e-9;

% 各类违反度的无量纲化尺度。正式实验中应与物理阈值相匹配。
cfg.constraint.scale.terrain = cfg.constraint.clearance;
% [逐行说明] 计算或更新 `cfg.constraint.scale.static`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.static = cfg.constraint.staticSafety + cfg.uav.radius;
% [逐行说明] 计算或更新 `cfg.constraint.scale.dynamic`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.dynamic = cfg.constraint.dynamicSafety + cfg.uav.radius;
% [逐行说明] 计算或更新 `cfg.constraint.scale.climb`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.climb = cfg.uav.maxClimbAngle;
% [逐行说明] 计算或更新 `cfg.constraint.scale.curvature`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.curvature = cfg.uav.maxCurvature;
% [逐行说明] 计算或更新 `cfg.constraint.scale.airSpeed`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.airSpeed = cfg.uav.maxAirSpeed;
% [逐行说明] 计算或更新 `cfg.constraint.scale.acceleration`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.acceleration = cfg.uav.maxAcceleration;
% [逐行说明] 计算或更新 `cfg.constraint.scale.energy`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.energy = cfg.uav.batteryEnergy;
% [逐行说明] 计算或更新 `cfg.constraint.scale.boundary`，供后续算法、评价或日志步骤使用。
cfg.constraint.scale.boundary = 1.0;

% 总违反度 CV 中的权重。默认各大类相同，避免人为偏向某一约束。
cfg.constraint.weight.terrain = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.static`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.static = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.dynamic`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.dynamic = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.climb`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.climb = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.curvature`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.curvature = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.airSpeed`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.airSpeed = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.acceleration`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.acceleration = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.energy`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.energy = 1.0;
% [逐行说明] 计算或更新 `cfg.constraint.weight.boundary`，供后续算法、评价或日志步骤使用。
cfg.constraint.weight.boundary = 1.0;

%% 4) 目标函数及归一化
cfg.objective.weights.length = 0.35;
% [逐行说明] 计算或更新 `cfg.objective.weights.energy`，供后续算法、评价或日志步骤使用。
cfg.objective.weights.energy = 0.35;
% [逐行说明] 计算或更新 `cfg.objective.weights.risk`，供后续算法、评价或日志步骤使用。
cfg.objective.weights.risk = 0.15;
% [逐行说明] 计算或更新 `cfg.objective.weights.smoothness`，供后续算法、评价或日志步骤使用。
cfg.objective.weights.smoothness = 0.15;
% [逐行说明] 计算或更新 `cfg.objective.weights.time`，供后续算法、评价或日志步骤使用。
cfg.objective.weights.time = 0.00; % fixed groundspeed: time duplicates normalized length

% 归一化基准必须在实验前固定。make_problem 会根据起终点自动补齐
% referenceLength/referenceTime；其余基准应由场景或平台给出。
cfg.objective.norm.referenceLength = [];
% [逐行说明] 计算或更新 `cfg.objective.norm.referenceEnergy`，供后续算法、评价或日志步骤使用。
cfg.objective.norm.referenceEnergy = cfg.uav.batteryEnergy;
% [逐行说明] 计算或更新 `cfg.objective.norm.referenceRisk`，供后续算法、评价或日志步骤使用。
cfg.objective.norm.referenceRisk = 100.0;
% [逐行说明] 计算或更新 `cfg.objective.norm.referenceSmoothness`，供后续算法、评价或日志步骤使用。
cfg.objective.norm.referenceSmoothness = 1.0;
% [逐行说明] 计算或更新 `cfg.objective.norm.referenceTime`，供后续算法、评价或日志步骤使用。
cfg.objective.norm.referenceTime = [];

%% 5) 风险模型
cfg.risk.terrainScale = 40.0;            % 低净空风险衰减尺度[m]
% [逐行说明] 计算或更新 `cfg.risk.staticScale`，供后续算法、评价或日志步骤使用。
cfg.risk.staticScale = 35.0;             % 静态障碍风险衰减尺度[m]
% [逐行说明] 计算或更新 `cfg.risk.dynamicScale`，供后续算法、评价或日志步骤使用。
cfg.risk.dynamicScale = 45.0;            % 动态障碍风险衰减尺度[m]
% [逐行说明] 计算或更新 `cfg.risk.maxExponent`，供后续算法、评价或日志步骤使用。
cfg.risk.maxExponent = 50;                % 防止 exp 数值溢出

%% 6) 能耗模型
cfg.energy.model = 'A';                  % 'A' 开发级；'B' 论文级旋翼模型
% [逐行说明] 计算或更新 `cfg.energy.A.cLength`，供后续算法、评价或日志步骤使用。
cfg.energy.A.cLength = 35.0;             % 距离项[J/m]
% [逐行说明] 计算或更新 `cfg.energy.A.cClimb`，供后续算法、评价或日志步骤使用。
cfg.energy.A.cClimb = 220.0;             % 正爬升项[J/m]
% [逐行说明] 计算或更新 `cfg.energy.A.cTurn`，供后续算法、评价或日志步骤使用。
cfg.energy.A.cTurn = 120.0;              % 转弯项[J/rad^2]
% [逐行说明] 计算或更新 `cfg.energy.A.cAir`，供后续算法、评价或日志步骤使用。
cfg.energy.A.cAir = 2.0;                 % 空速平方积分系数

% B 级旋翼功率模型参数。示例值用于代码运行，正式论文必须依据平台或文献校准。
cfg.energy.B.P0 = 79.86;                 % 桨叶剖面功率[W]
% [逐行说明] 计算或更新 `cfg.energy.B.Pi`，供后续算法、评价或日志步骤使用。
cfg.energy.B.Pi = 88.63;                 % 诱导功率[W]
% [逐行说明] 计算或更新 `cfg.energy.B.Utip`，供后续算法、评价或日志步骤使用。
cfg.energy.B.Utip = 120.0;               % 桨尖速度[m/s]
% [逐行说明] 计算或更新 `cfg.energy.B.v0`，供后续算法、评价或日志步骤使用。
cfg.energy.B.v0 = 4.03;                  % 悬停平均诱导速度[m/s]
% [逐行说明] 计算或更新 `cfg.energy.B.d0`，供后续算法、评价或日志步骤使用。
cfg.energy.B.d0 = 0.6;                   % 机身阻力比
% [逐行说明] 计算或更新 `cfg.energy.B.rho`，供后续算法、评价或日志步骤使用。
cfg.energy.B.rho = 1.225;                % 空气密度[kg/m^3]
% [逐行说明] 计算或更新 `cfg.energy.B.solidity`，供后续算法、评价或日志步骤使用。
cfg.energy.B.solidity = 0.05;            % 旋翼实度
% [逐行说明] 计算或更新 `cfg.energy.B.rotorArea`，供后续算法、评价或日志步骤使用。
cfg.energy.B.rotorArea = 0.503;           % 总旋翼面积[m^2]
% [逐行说明] 计算或更新 `cfg.energy.B.climbEfficiency`，供后续算法、评价或日志步骤使用。
cfg.energy.B.climbEfficiency = 0.75;      % 爬升效率
% [逐行说明] 计算或更新 `cfg.energy.B.descentCoeff`，供后续算法、评价或日志步骤使用。
cfg.energy.B.descentCoeff = 45.0;         % 下降修正系数[W/(m/s)]

%% 7) 主优化器
cfg.algorithm.N = 60;
% [逐行说明] 计算或更新 `cfg.algorithm.MaxFEs`，供后续算法、评价或日志步骤使用。
cfg.algorithm.MaxFEs = 50000;
% [逐行说明] 计算或更新 `cfg.algorithm.alpha`，供后续算法、评价或日志步骤使用。
cfg.algorithm.alpha = 0.30;             % 高地策略个体历史学习率
% [逐行说明] 计算或更新 `cfg.algorithm.beta`，供后续算法、评价或日志步骤使用。
cfg.algorithm.beta = 0.20;              % 快速俯冲历史混合系数
% [逐行说明] 计算或更新 `cfg.algorithm.eliteFraction`，供后续算法、评价或日志步骤使用。
cfg.algorithm.eliteFraction = 0.10;      % 围猎精英比例
% [逐行说明] 计算或更新 `cfg.algorithm.logEveryFE`，供后续算法、评价或日志步骤使用。
cfg.algorithm.logEveryFE = 50;           % 收敛日志采样间隔
% [逐行说明] 计算或更新 `cfg.algorithm.seed`，供后续算法、评价或日志步骤使用。
cfg.algorithm.seed = 1;
% [逐行说明] 计算或更新 `cfg.algorithm.verbose`，供后续算法、评价或日志步骤使用。
cfg.algorithm.verbose = true;
% [逐行说明] 计算或更新 `cfg.algorithm.assertInvariants`，供后续算法、评价或日志步骤使用。
cfg.algorithm.assertInvariants = true;   % 开发阶段建议开启，正式大实验可关闭以节省少量时间

%% 8) 阶段内自适应策略选择 ASA
cfg.strategy.enabled = true;
% [逐行说明] 计算或更新 `cfg.strategy.window`，供后续算法、评价或日志步骤使用。
cfg.strategy.window = 8;                 % 每个策略近期奖励窗口长度
% [逐行说明] 计算或更新 `cfg.strategy.rho`，供后续算法、评价或日志步骤使用。
cfg.strategy.rho = 0.30;                 % Q 指数平滑系数
% [逐行说明] 计算或更新 `cfg.strategy.temperature`，供后续算法、评价或日志步骤使用。
cfg.strategy.temperature = 0.20;         % softmax 温度
% [逐行说明] 计算或更新 `cfg.strategy.pMinExploration`，供后续算法、评价或日志步骤使用。
cfg.strategy.pMinExploration = 0.08;     % 三策略分支的概率下限
% [逐行说明] 计算或更新 `cfg.strategy.pMinPair`，供后续算法、评价或日志步骤使用。
cfg.strategy.pMinPair = 0.15;            % 两策略分支的概率下限
% [逐行说明] 计算或更新 `cfg.strategy.warmupCalls`，供后续算法、评价或日志步骤使用。
cfg.strategy.warmupCalls = 5;             % 每策略最少预热调用次数
% [逐行说明] 计算或更新 `cfg.strategy.unusedDecay`，供后续算法、评价或日志步骤使用。
cfg.strategy.unusedDecay = 0.02;          % 长期未调用 Q 向中性先验回归速度
% [逐行说明] 计算或更新 `cfg.strategy.qPrior`，供后续算法、评价或日志步骤使用。
cfg.strategy.qPrior = 0.0;
% [逐行说明] 计算或更新 `cfg.strategy.rewardCap`，供后续算法、评价或日志步骤使用。
cfg.strategy.rewardCap = 1.0;            % 单次单位 FE 奖励截断
% [逐行说明] 计算或更新 `cfg.strategy.lambdaRepair`，供后续算法、评价或日志步骤使用。
cfg.strategy.lambdaRepair = 0.30;         % 修复贡献记给搜索策略的比例
cfg.strategy.selector = 'softmax';
cfg.strategy.creditMode = 'split';
cfg.strategy.costMode = 'actual';
cfg.strategy.fixedCost = 1;
cfg.strategy.recordEvents = true;
% [逐行说明] 计算或更新 `cfg.strategy.crossReward`，供后续算法、评价或日志步骤使用。
cfg.strategy.crossReward = 0.20;           % 不可行 -> 可行跃迁奖励
% [逐行说明] 计算或更新 `cfg.strategy.lossPenalty`，供后续算法、评价或日志步骤使用。
cfg.strategy.lossPenalty = 0.20;          % 可行 -> 不可行惩罚
% [逐行说明] 计算或更新 `cfg.strategy.lowFeasibleEtaF`，供后续算法、评价或日志步骤使用。
cfg.strategy.lowFeasibleEtaF = 0.25;      % 可行率低时的目标奖励权重
% [逐行说明] 计算或更新 `cfg.strategy.lowFeasibleEtaV`，供后续算法、评价或日志步骤使用。
cfg.strategy.lowFeasibleEtaV = 0.75;      % 可行率低时的违反奖励权重
% [逐行说明] 计算或更新 `cfg.strategy.highFeasibleEtaF`，供后续算法、评价或日志步骤使用。
cfg.strategy.highFeasibleEtaF = 0.75;     % 可行率高时的目标奖励权重
% [逐行说明] 计算或更新 `cfg.strategy.highFeasibleEtaV`，供后续算法、评价或日志步骤使用。
cfg.strategy.highFeasibleEtaV = 0.25;     % 可行率高时的违反奖励权重
% [逐行说明] 计算或更新 `cfg.strategy.feasibleLowThreshold`，供后续算法、评价或日志步骤使用。
cfg.strategy.feasibleLowThreshold = 0.20;
% [逐行说明] 计算或更新 `cfg.strategy.feasibleHighThreshold`，供后续算法、评价或日志步骤使用。
cfg.strategy.feasibleHighThreshold = 0.80;

%% 9) 停滞恢复
cfg.stagnation.enabled = true;
% [逐行说明] 计算或更新 `cfg.stagnation.windowEquivalentPopulations`，供后续算法、评价或日志步骤使用。
cfg.stagnation.windowEquivalentPopulations = 10; % 约等于 10*N 次 FE 无改进
% [逐行说明] 计算或更新 `cfg.stagnation.improvementTolerance`，供后续算法、评价或日志步骤使用。
cfg.stagnation.improvementTolerance = 1e-6;
% [逐行说明] 计算或更新 `cfg.stagnation.diversityMin`，供后续算法、评价或日志步骤使用。
cfg.stagnation.diversityMin = 0.025;
% [逐行说明] 计算或更新 `cfg.stagnation.restartFraction`，供后续算法、评价或日志步骤使用。
cfg.stagnation.restartFraction = 0.15;
% [逐行说明] 计算或更新 `cfg.stagnation.overrideUpdates`，供后续算法、评价或日志步骤使用。
cfg.stagnation.overrideUpdates = 2;       % 被重置个体允许探索门控覆盖的更新次数
% [逐行说明] 计算或更新 `cfg.stagnation.cooldownFEs`，供后续算法、评价或日志步骤使用。
cfg.stagnation.cooldownFEs = 3*cfg.algorithm.N;

%% 10) 约束类型驱动修复 CDR
cfg.repair.enabled = true;
% [逐行说明] 计算或更新 `cfg.repair.applyDuringInitialization`，供后续算法、评价或日志步骤使用。
cfg.repair.applyDuringInitialization = true;
% [逐行说明] 计算或更新 `cfg.repair.maxRounds`，供后续算法、评价或日志步骤使用。
cfg.repair.maxRounds = 4;
% [逐行说明] 计算或更新 `cfg.repair.maxInitRounds`，供后续算法、评价或日志步骤使用。
cfg.repair.maxInitRounds = 2;
% [逐行说明] 计算或更新 `cfg.repair.stepGain`，供后续算法、评价或日志步骤使用。
cfg.repair.stepGain = 0.75;
% [逐行说明] 计算或更新 `cfg.repair.margin`，供后续算法、评价或日志步骤使用。
cfg.repair.margin = 2.0;                  % 物理空间额外修复裕度[m]
% [逐行说明] 计算或更新 `cfg.repair.maxNormalizedMove`，供后续算法、评价或日志步骤使用。
cfg.repair.maxNormalizedMove = 0.08;      % 单轮单控制点最大归一化移动
% [逐行说明] 计算或更新 `cfg.repair.allowTerrain`，供后续算法、评价或日志步骤使用。
cfg.repair.allowTerrain = true;
% [逐行说明] 计算或更新 `cfg.repair.allowStatic`，供后续算法、评价或日志步骤使用。
cfg.repair.allowStatic = true;
% [逐行说明] 计算或更新 `cfg.repair.allowDynamic`，供后续算法、评价或日志步骤使用。
cfg.repair.allowDynamic = true;
% [逐行说明] 计算或更新 `cfg.repair.allowClimb`，供后续算法、评价或日志步骤使用。
cfg.repair.allowClimb = true;
% [逐行说明] 计算或更新 `cfg.repair.allowCurvature`，供后续算法、评价或日志步骤使用。
cfg.repair.allowCurvature = true;
% [逐行说明] 计算或更新 `cfg.repair.acceptOnlyIfDebBetter`，供后续算法、评价或日志步骤使用。
cfg.repair.acceptOnlyIfDebBetter = false; % false: 返回所有修复候选，由主程序统一 Deb 选择

%% 11) 地形感知混合初始化 TAI
cfg.initialization.enabled = true;
% [逐行说明] 计算或更新 `cfg.initialization.seedFraction`，供后续算法、评价或日志步骤使用。
cfg.initialization.seedFraction = 0.30;
% [逐行说明] 计算或更新 `cfg.initialization.localTentFraction`，供后续算法、评价或日志步骤使用。
cfg.initialization.localTentFraction = 0.45;
% [逐行说明] 计算或更新 `cfg.initialization.globalFraction`，供后续算法、评价或日志步骤使用。
cfg.initialization.globalFraction = 0.25;
% [逐行说明] 计算或更新 `cfg.initialization.numSeedPaths`，供后续算法、评价或日志步骤使用。
cfg.initialization.numSeedPaths = 5;
% [逐行说明] 计算或更新 `cfg.initialization.gridSize`，供后续算法、评价或日志步骤使用。
cfg.initialization.gridSize = [55, 55];
% [逐行说明] 计算或更新 `cfg.initialization.seedNoise`，供后续算法、评价或日志步骤使用。
cfg.initialization.seedNoise = 0.03;
% [逐行说明] 计算或更新 `cfg.initialization.tentSigma`，供后续算法、评价或日志步骤使用。
cfg.initialization.tentSigma = 0.07;
% [逐行说明] 计算或更新 `cfg.initialization.globalLateralScale`，供后续算法、评价或日志步骤使用。
cfg.initialization.globalLateralScale = 0.25;
% [逐行说明] 计算或更新 `cfg.initialization.globalAltitudeMargin`，供后续算法、评价或日志步骤使用。
cfg.initialization.globalAltitudeMargin = [10, 70];
% [逐行说明] 计算或更新 `cfg.initialization.hausdorffThreshold`，供后续算法、评价或日志步骤使用。
cfg.initialization.hausdorffThreshold = 0.06;
% [逐行说明] 计算或更新 `cfg.initialization.maxAstarExpansions`，供后续算法、评价或日志步骤使用。
cfg.initialization.maxAstarExpansions = 2e5;
% [逐行说明] 计算或更新 `cfg.initialization.seedWeightSets`，供后续算法、评价或日志步骤使用。
cfg.initialization.seedWeightSets = [ ...
    1.0, 0.2, 0.2; ... % 长度优先
    1.0, 0.8, 0.3; ... % 坡度优先
    1.0, 0.3, 1.0; ... % 风险优先
    0.8, 1.2, 0.5; ...
    1.2, 0.5, 1.2];

%% 12) 实验与保存
cfg.experiment.numRuns = 30;
% [逐行说明] 计算或更新 `cfg.experiment.outputDir`，供后续算法、评价或日志步骤使用。
cfg.experiment.outputDir = fullfile('results');
% [逐行说明] 计算或更新 `cfg.experiment.saveFullLog`，供后续算法、评价或日志步骤使用。
cfg.experiment.saveFullLog = true;
% [逐行说明] 计算或更新 `cfg.experiment.saveCsvSummary`，供后续算法、评价或日志步骤使用。
cfg.experiment.saveCsvSummary = true;
% [逐行说明] 计算或更新 `cfg.experiment.useParallel`，供后续算法、评价或日志步骤使用。
cfg.experiment.useParallel = false;
% [逐行说明] 计算或更新 `cfg.experiment.failFast`，供后续算法、评价或日志步骤使用。
cfg.experiment.failFast = false;

%% 13) 真实 DEM 数据与性能控制
% 数据完整性核验默认开启。正式论文实验建议保持 true；只有在用户明确替换
% GeoTIFF 并同步更新 dem_catalog/manifest 后才可关闭或更新摘要。
cfg.data.verifyChecksum = true;
% 保存运行结果时删除可确定性重建的 griddedInterpolant/B 样条缓存，减小文件。
cfg.experiment.stripRuntimeCacheBeforeSave = true;
% 并行模式按“独立运行”并行，固定每个 runID 的随机种子，不在单个优化器
% 内部改变评价顺序。无 Parallel Computing Toolbox 时自动回退到串行。
cfg.experiment.autoStartParallelPool = true;

end
