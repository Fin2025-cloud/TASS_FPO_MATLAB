function knots = clamped_uniform_knots(numberOfControlPoints, degree)
%CLAMPED_UNIFORM_KNOTS 构造开放夹持均匀 B 样条节点向量。
%
% 该函数独立于 decode_bspline_path.m，便于环境初始化阶段预先计算并缓存
% 节点向量和基函数矩阵。缓存只消除重复计算，不改变任何节点位置或曲线值。

numberOfInternalKnots = numberOfControlPoints - degree - 1;
if numberOfInternalKnots > 0
    internalKnots = (1:numberOfInternalKnots)/(numberOfInternalKnots+1);
else
    internalKnots = [];
end
knots = [zeros(1,degree+1),internalKnots,ones(1,degree+1)];
end
