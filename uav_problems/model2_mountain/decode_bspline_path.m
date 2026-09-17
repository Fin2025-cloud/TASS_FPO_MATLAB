function path = decode_bspline_path(z,env,cfg,physicalLB,physicalUB)
%DECODE_BSPLINE_PATH 将 [0,1]^(3K) 决策向量解码为夹持 B 样条轨迹。
%
% 加速说明
% -------------------------------------------------------------------------
% 完整控制点数量、样条次数、节点向量、参数 u 和基函数矩阵只由 K、M 与
% splineDegree 决定，与候选解 z 无关。prepare_environment_cache 在问题创建
% 时预计算这些数据；本函数仅复用它们并执行 B*controlPoints。缓存缺失或
% 配置不匹配时，自动执行与旧版本相同的现场计算。

z=double(z(:)');
K=cfg.path.K;
if numel(z)~=3*K
    error('decode_bspline_path:Dimension', ...
        'Expected %d decision variables, but received %d.',3*K,numel(z));
end
physicalLB=double(physicalLB(:)');
physicalUB=double(physicalUB(:)');
if numel(physicalLB)~=3*K || numel(physicalUB)~=3*K
    error('decode_bspline_path:PhysicalBounds', ...
        'Physical lower and upper bounds must each contain 3*K elements.');
end

physicalVector=physicalLB+z.*(physicalUB-physicalLB);
internalControlPoints=reshape(physicalVector,3,K)';
controlPoints=[env.start;internalControlPoints;env.goal];
numberOfControlPoints=size(controlPoints,1);
degree=min(cfg.path.splineDegree,numberOfControlPoints-1);

useCache=false;
if isfield(env,'cache') && isfield(env.cache,'path')
    c=env.cache.path;
    useCache=isfield(c,'K') && isfield(c,'M') && ...
        c.K==K && c.M==cfg.path.M && ...
        c.numberOfControlPoints==numberOfControlPoints && c.degree==degree;
end
if useCache
    knots=c.knots;
    u=c.u;
    B=c.basis;
else
    knots=clamped_uniform_knots(numberOfControlPoints,degree);
    u=linspace(0,1,cfg.path.M)';
    B=bspline_basis_matrix(u,numberOfControlPoints,degree,knots);
end
P=B*controlPoints;

path=struct('z',z,'physicalVector',physicalVector, ...
    'internalControlPoints',internalControlPoints, ...
    'controlPoints',controlPoints,'degree',degree,'knots',knots, ...
    'u',u,'basis',B,'P',P,'usedCachedBasis',useCache);
end
