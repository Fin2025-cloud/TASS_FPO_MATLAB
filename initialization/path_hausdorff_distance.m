function distance = path_hausdorff_distance(A, B)
%PATH_HAUSDORFF_DISTANCE 计算两条二维离散路径的对称 Hausdorff 距离。
%
% d_H(A,B)=max(max_a min_b ||a-b||, max_b min_a ||b-a||)。
% 该指标只用于初始化通道去重，不参与优化目标或 FE 计数。

% 任一路径为空时无法定义有限通道距离。
if isempty(A) || isempty(B)
    % 返回无穷大，确保空路径不会被错误判为重复。
    distance = inf;

    % 结束函数。
    return;
end

% 显式计算所有 A 点与 B 点之间的 x 坐标差矩阵。
deltaX = bsxfun(@minus, A(:, 1), B(:, 1)');

% 显式计算所有 A 点与 B 点之间的 y 坐标差矩阵。
deltaY = bsxfun(@minus, A(:, 2), B(:, 2)');

% 计算两条路径所有离散点对之间的平方距离矩阵。
distanceSquared = deltaX .^ 2 + deltaY .^ 2;

% 对每个 A 点取得到 B 路径最近点的距离。
directedAtoB = sqrt(min(distanceSquared, [], 2));

% 对每个 B 点取得到 A 路径最近点的距离。
directedBtoA = sqrt(min(distanceSquared, [], 1));

% 取两个有向最大最小距离中的较大值，得到对称 Hausdorff 距离。
distance = max(max(directedAtoB), max(directedBtoA));
end
