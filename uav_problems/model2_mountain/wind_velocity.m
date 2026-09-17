function W = wind_velocity(env, P, t)
%WIND_VELOCITY 返回指定三维位置与时刻的风速向量。
%
% 输入
% -------------------------------------------------------------------------
% env : 环境结构，至少包含 env.wind；地形相关风还需要 env.terrain/env.zLim。
% P   : N×3 查询点矩阵，每行依次为 [x,y,z]，单位 m。
% t   : 标量或 N×1 时间向量，单位 s。
%
% 输出
% -------------------------------------------------------------------------
% W   : N×3 风速矩阵，每行依次为 [W_x,W_y,W_z]，单位 m/s。
%
% 可复现性说明
% -------------------------------------------------------------------------
% 本函数不调用随机数。场景噪声和风场参数必须在环境构建阶段一次性生成，
% 不能在每次路径评价时重新采样，否则相同候选会得到不同目标值。

% 若没有查询点，返回尺寸正确的空风速矩阵。
if isempty(P)
    % 空矩阵保留三列，便于调用方直接进行速度运算。
    W = zeros(0, 3);

    % 结束函数。
    return;
end

% 强制查询点为双精度数值。
P = double(P);

% 检查每个查询点是否恰好包含三个空间坐标。
if size(P, 2) ~= 3
    % 输入形状不合法时显式报错，避免错误广播产生伪造风速。
    error('wind_velocity:InvalidPointShape', 'P must be an N-by-3 matrix.');
end

% 读取查询点数量。
n = size(P, 1);

% 若时间为标量，则复制为每个查询点对应的时间。
if isscalar(t)
    % 生成 N×1 时间列向量。
    t = repmat(double(t), n, 1);
else
    % 非标量时间统一转换为 N×1 列向量。
    t = double(t(:));
end

% 检查时间数量是否与查询点数量一致。
if numel(t) ~= n
    % 一点一时刻关系被破坏时终止计算。
    error('wind_velocity:SizeMismatch', ...
        't must be scalar or contain exactly one value for each point.');
end

% 读取风场配置结构。
wind = env.wind;

% 将风场类型转换为小写字符，统一分支比较。
type = lower(char(wind.type));

% 根据风场类型计算风速。
switch type
    case 'constant'
        % 把常风向量统一成 1×3 行向量。
        constantWind = double(wind.constant(:)');

        % 检查常风必须包含三个分量。
        if numel(constantWind) ~= 3
            % 风速分量数量错误会导致空速计算失真，因此显式报错。
            error('wind_velocity:InvalidConstantWind', ...
                'Constant wind must contain exactly three components.');
        end

        % 把同一常风向量复制到所有查询点。
        W = repmat(constantWind, n, 1);

    case 'terrain_composite'
        % 把基础风向量统一成 1×3 行向量。
        baseWind = double(wind.base(:)');

        % 把基础风复制到所有查询点。
        base = repmat(baseWind, n, 1);

        % 取环境允许高度区间的中点作为垂直切变参考高度。
        zReference = mean(env.zLim);

        % 计算每个查询点相对参考高度的高度差。
        relativeZ = P(:, 3) - zReference;

        % 将每个高度差乘以三维切变系数，得到 N×3 切变风。
        shear = bsxfun(@times, relativeZ, double(wind.shear(:)'));

        % 计算查询点相对涡旋中心的 x 偏移。
        dx = P(:, 1) - wind.vortexCenter(1);

        % 计算查询点相对涡旋中心的 y 偏移。
        dy = P(:, 2) - wind.vortexCenter(2);

        % 在半径平方中加入 80^2 软核，避免涡旋中心速度奇异。
        radiusSquared = dx .^ 2 + dy .^ 2 + 80 ^ 2;

        % 计算平滑后的切向速度幅值。
        tangentialSpeed = wind.vortexStrength ./ sqrt(radiusSquared);

        % 构造水平切向单位方向的未归一化向量。
        tangentDirection = [-dy, dx, zeros(n, 1)];

        % 计算切向方向归一化与速度幅值组合系数。
        tangentScale = tangentialSpeed ./ (sqrt(radiusSquared) + eps);

        % 将每个点的切向方向乘以对应速度系数。
        vortex = bsxfun(@times, tangentDirection, tangentScale);

        % 查询每个位置的地形高度，用于构造近地垂直风。
        terrainH = terrain_height(env, P(:, 1), P(:, 2));

        % 强制地形高度为列向量。
        terrainH = terrainH(:);

        % 对地图外查询点使用环境最低高度作为防御值。
        terrainH(~isfinite(terrainH)) = env.zLim(1);

        % 计算 UAV 相对地形表面的非负高度。
        relativeHeight = max(P(:, 3) - terrainH, 0);

        % 构造随离地高度衰减、随水平位置变化的垂直风分量。
        vertical = wind.verticalScale .* exp(-relativeHeight / 120) .* ...
            sin(P(:, 1) / 140) .* cos(P(:, 2) / 170);

        % 汇总基础风、垂直切变和水平涡旋。
        W = base + shear + vortex;

        % 把地形相关垂直风叠加到 z 分量。
        W(:, 3) = W(:, 3) + vertical;

    case 'function_handle'
        % 调用用户提供的确定性风场函数。
        W = wind.functionHandle(P, t);

        % 检查自定义风场是否返回 N×3 数值矩阵。
        if ~isequal(size(W), [n, 3])
            % 输出尺寸错误时终止评价，避免隐式扩展。
            error('wind_velocity:InvalidFunctionOutput', ...
                'Custom wind function must return an N-by-3 matrix.');
        end

    otherwise
        % 未识别的风场类型属于配置错误，直接报告类型名称。
        error('wind_velocity:UnknownType', ...
            'Unknown wind type: %s', char(wind.type));
end

% 最后检查全部风速分量是否为有限数。
if any(~isfinite(W(:)))
    % 非有限风速会污染空速、能耗和可行性，因此禁止继续。
    error('wind_velocity:NonfiniteOutput', ...
        'Wind field returned NaN or Inf values.');
end
end
