function h = terrain_height(env,xq,yq)
%TERRAIN_HEIGHT 查询合成或真实栅格地形的双线性高程。
%
% 若 make_problem 已构造运行时缓存，则复用 griddedInterpolant；否则回退到
% 原始 interp2 实现。两条路径均使用线性插值且地图外返回 NaN，不使用最近
% 外推，因此缓存不会改变边界可行性定义。

if isfield(env,'cache') && isfield(env.cache,'terrainInterpolant')
    % griddedInterpolant 的输入顺序对应 Z 的行坐标 y、列坐标 x。
    h=env.cache.terrainInterpolant(double(yq),double(xq));
else
    h=interp2(env.terrain.x,env.terrain.y,env.terrain.Z, ...
        double(xq),double(yq),'linear',NaN);
end
end
