function B = bspline_basis_matrix(u, nCtrl, degree, knots)
%BSPLINE_BASIS_MATRIX 使用 Cox-de Boor 递推计算 B 样条基函数矩阵。
%
% 输入
% -------------------------------------------------------------------------
% u      : M×1 参数向量，范围应位于 [0,1]；
% nCtrl  : 控制点总数，包括固定起点和终点；
% degree : B 样条次数 p；
% knots  : 开放夹持节点向量，长度应为 nCtrl+p+1。
%
% 输出
% -------------------------------------------------------------------------
% B      : M×nCtrl 基函数矩阵，轨迹点通过 P=B*controlPoints 获得。
%
% 数值性质
% -------------------------------------------------------------------------
% 每行基函数理论和为 1；u=1 时显式令最后一个基函数为 1，确保轨迹严格经过
% 终点。最后的行归一化只修正浮点误差，不改变基函数理论形状。

% 把参数输入统一转换为双精度列向量。
u = double(u(:));

% 检查节点向量长度是否满足 B 样条定义。
if numel(knots) ~= nCtrl + degree + 1
    % 节点数量错误时停止计算，避免返回错误轨迹。
    error('bspline_basis_matrix:KnotCount', ...
        'The knot vector must contain nCtrl+degree+1 elements.');
end

% 取得参数采样点数量。
numberOfSamples = numel(u);

% 为零次基函数预分配足够列数。
N = zeros(numberOfSamples, nCtrl + degree);

% 逐个构造零次基函数的半开区间指示函数。
for i = 1:(nCtrl + degree)
    % 当 u 落入 [U_i,U_{i+1}) 时，该零次基函数取 1。
    N(:, i) = double(u >= knots(i) & u < knots(i + 1));
end

% 找出参数精确等于终点 1 的行。
endRows = find(abs(u - 1) <= 10 * eps);

% 若存在终点参数，先把这些行全部清零。
if ~isempty(endRows)
    % 清零避免半开区间定义使终点没有任何非零基函数。
    N(endRows, :) = 0;

    % 在零次初始化阶段把终点质量放到第 nCtrl 列。
    N(endRows, nCtrl) = 1;
end

% 从一次到目标次数逐阶执行 Cox-de Boor 递推。
for currentDegree = 1:degree
    % 为当前次数基函数预分配列数。
    Nk = zeros(numberOfSamples, nCtrl + degree - currentDegree);

    % 逐个计算当前次数下的每个基函数。
    for i = 1:(nCtrl + degree - currentDegree)
        % 计算递推左项分母 U_{i+k}-U_i。
        leftDenominator = knots(i + currentDegree) - knots(i);

        % 计算递推右项分母 U_{i+k+1}-U_{i+1}。
        rightDenominator = knots(i + currentDegree + 1) - knots(i + 1);

        % 初始化递推左项为零列向量。
        leftTerm = zeros(numberOfSamples, 1);

        % 初始化递推右项为零列向量。
        rightTerm = zeros(numberOfSamples, 1);

        % 只有左分母为正时才计算左递推项。
        if leftDenominator > 0
            % 按 Cox-de Boor 公式计算左项。
            leftTerm = ((u - knots(i)) ./ leftDenominator) .* N(:, i);
        end

        % 只有右分母为正时才计算右递推项。
        if rightDenominator > 0
            % 按 Cox-de Boor 公式计算右项。
            rightTerm = ((knots(i + currentDegree + 1) - u) ./ ...
                rightDenominator) .* N(:, i + 1);
        end

        % 将左右两项相加得到当前基函数列。
        Nk(:, i) = leftTerm + rightTerm;
    end

    % 用当前次数基函数替换上一次数基函数，供下一轮递推使用。
    N = Nk;
end

% 只保留与实际控制点一一对应的前 nCtrl 列。
B = N(:, 1:nCtrl);

% 对终点参数行再次施加夹持端点条件。
if ~isempty(endRows)
    % 把终点行所有基函数置零。
    B(endRows, :) = 0;

    % 令终点行最后一个基函数严格等于 1。
    B(endRows, end) = 1;
end

% 计算每个参数点所有基函数之和。
rowSum = sum(B, 2);

% 识别行和大于 eps 的有效行。
validRows = rowSum > eps;

% 若存在有效行，则显式按行归一化以消除累计浮点误差。
if any(validRows)
    % 使用 bsxfun 避免 M×nCtrl 与 M×1 的隐式扩展差异。
    B(validRows, :) = bsxfun(@rdivide, B(validRows, :), rowSum(validRows));
end
end
