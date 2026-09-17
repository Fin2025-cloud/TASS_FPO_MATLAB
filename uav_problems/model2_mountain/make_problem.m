function problem = make_problem(env, cfg)
%MAKE_PROBLEM 将环境与配置封装为所有优化器共享的统一问题接口。
%
% 设计目的
% -------------------------------------------------------------------------
% 优化算法只在归一化空间 [0,1]^D 中运行，不直接接触米、秒或焦耳。所有
% 物理坐标映射、B 样条解码、约束评价和修复均通过 problem 中的函数句柄
% 调用。这样可以保证 FPO、TAAS-FPO 和比较算法使用完全相同的评价模型。
%
% problem 主要字段
% -------------------------------------------------------------------------
% dim/lb/ub       : 归一化搜索维数与边界；
% physicalLB/UB   : 内部控制点的物理坐标边界；
% evaluate        : 统一路径评价函数；
% decode          : 路径解码函数；
% repair          : 约束类型驱动修复函数；
% initializer     : 地形感知混合初始化函数；
% env/cfg         : 冻结后的环境与配置副本。

% 检查配置字段、参数范围和目标权重是否合法。
validate_config(cfg);

% 在任何函数句柄捕获环境之前，构造确定性的只读地形和 B 样条缓存。
% 该步骤不改变 DEM、搜索空间、目标函数、约束或函数评价次数。
env = prepare_environment_cache(env,cfg);

% 读取内部控制点数量。
K = cfg.path.K;

% 每个内部控制点含 x、y、z 三个变量，因此总维数为 3K。
D = 3 * K;

% 构造单个内部控制点的物理下界 [x_min,y_min,z_min]。
singleLowerBound = [env.xLim(1), env.yLim(1), env.zLim(1)];

% 构造单个内部控制点的物理上界 [x_max,y_max,z_max]。
singleUpperBound = [env.xLim(2), env.yLim(2), env.zLim(2)];

% 将单点下界按控制点数量重复，得到 1×3K 物理下界。
physicalLB = repmat(singleLowerBound, 1, K);

% 将单点上界按控制点数量重复，得到 1×3K 物理上界。
physicalUB = repmat(singleUpperBound, 1, K);

% 计算起点到终点的三维直线距离。
straightLength = norm(env.goal - env.start);

% 若用户未显式指定参考长度，则使用直线距离作为预先固定基准。
if isempty(cfg.objective.norm.referenceLength)
    % 用 eps 防止起终点重合导致参考长度为零。
    cfg.objective.norm.referenceLength = max(straightLength, eps);
end

% 若用户未显式指定参考时间，则使用直线距离除以固定地速。
if isempty(cfg.objective.norm.referenceTime)
    % 用 eps 防止参考时间为零。
    cfg.objective.norm.referenceTime = max( ...
        straightLength / cfg.uav.groundSpeed, eps);
end

% 创建统一问题结构。
problem = struct();

% 使用环境标识构造可读问题名称。
problem.name = sprintf('UAV_%s', env.id);

% 标记问题类型，供初始化和实验脚本判断是否为 UAV 路径问题。
problem.kind = 'uav_path';

% 保存归一化决策维数。
problem.dim = D;

% 归一化空间所有维度的下界均为 0。
problem.lb = zeros(1, D);

% 归一化空间所有维度的上界均为 1。
problem.ub = ones(1, D);

% 保存内部控制点的物理下界。
problem.physicalLB = physicalLB;

% 保存内部控制点的物理上界。
problem.physicalUB = physicalUB;

% 保存环境副本，后续函数句柄使用该固定环境。
problem.env = env;

% 保存自动补齐参考基准后的配置副本。
problem.cfg = cfg;

% 创建统一评价函数句柄，输入只需要归一化决策向量 z。
problem.evaluate = @(z) evaluate_path(z, env, cfg, physicalLB, physicalUB);

% 创建统一解码函数句柄，供可视化和热启动使用。
problem.decode = @(z) decode_bspline_path(z, env, cfg, physicalLB, physicalUB);

% 创建统一修复函数句柄；修复函数本身不执行完整评价。
problem.repair = @(z, result, maxRounds) repair_path( ...
    z, result, env, cfg, physicalLB, physicalUB, maxRounds);

% 创建地形感知混合初始化函数句柄。
problem.initializer = @(N, isRestart) terrain_aware_initialization( ...
    problem, N, isRestart);
end
