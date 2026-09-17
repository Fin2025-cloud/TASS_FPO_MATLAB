function env = prepare_environment_cache(env,cfg)
%PREPARE_ENVIRONMENT_CACHE 构造只读运行时缓存，减少重复路径评价开销。
%
% 本函数只缓存两类确定性对象：
%   1. 同一地形栅格反复查询所需的 griddedInterpolant；
%   2. 固定 K、M、样条次数下完全不随候选解变化的 B 样条基函数矩阵。
%
% 数学等价性
% -------------------------------------------------------------------------
% 地形插值仍采用线性插值，越界仍返回 NaN；B 样条仍使用原始的开放夹持
% 均匀节点向量和 bspline_basis_matrix。缓存不降采样 DEM、不改变浮点类型、
% 不减少路径采样点，也不改变 FE 计数。

if ~isfield(env,'terrain') || ~all(isfield(env.terrain,{'x','y','Z'}))
    error('prepare_environment_cache:Terrain','Environment terrain is incomplete.');
end

x = double(env.terrain.x(:));
y = double(env.terrain.y(:));
Z = double(env.terrain.Z);
if size(Z,1)~=numel(y) || size(Z,2)~=numel(x)
    error('prepare_environment_cache:GridSize', ...
        'size(Z) must equal [numel(y),numel(x)].');
end
if any(diff(x)<=0) || any(diff(y)<=0)
    error('prepare_environment_cache:GridOrder', ...
        'Terrain x and y vectors must be strictly increasing.');
end

% griddedInterpolant 的维度顺序与 Z 的 [row(y),column(x)] 一致。
env.cache = struct();
env.cache.version = '1.1.1';
if exist('griddedInterpolant','class') || exist('griddedInterpolant','file')
    env.cache.terrainInterpolant = griddedInterpolant({y,x},Z,'linear','none');
end

numberOfControlPoints = cfg.path.K + 2;
degree = min(cfg.path.splineDegree,numberOfControlPoints-1);
knots = clamped_uniform_knots(numberOfControlPoints,degree);
u = linspace(0,1,cfg.path.M)';
B = bspline_basis_matrix(u,numberOfControlPoints,degree,knots);

env.cache.path = struct( ...
    'K',cfg.path.K, ...
    'M',cfg.path.M, ...
    'numberOfControlPoints',numberOfControlPoints, ...
    'degree',degree, ...
    'knots',knots, ...
    'u',u, ...
    'basis',B);
end
