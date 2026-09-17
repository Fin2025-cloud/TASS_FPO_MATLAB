function plot_environment_candidate(ax,env,cfg,viewMode)
%PLOT_ENVIRONMENT_CANDIDATE 清晰、快速地绘制候选环境。
%
% 本函数只修改可视化效果，不修改地形数据、风场模型、障碍物、
% 路径评价函数或算法运行结果。
%
% 与 v1.2.0 原版相比：
%   1) S5/S6 的风场箭头最多显示 4×3 个，避免遮挡地形；
%   2) quiver3 缩放因子由 65 改为 0.70，避免箭头异常过长；
%   3) 绘图完成后固定 X/Y/Z 范围，风箭头和动态轨迹不再把地形挤偏；
%   4) 动态障碍物轨迹只显示地图范围内的部分；
%   5) 相机目标固定在环境中心，使地形位于画面中心。
%
% 输入：
%   ax       - MATLAB 坐标轴句柄
%   env      - build_environment_candidate 生成的环境结构体
%   cfg      - environment_config 或 make_problem_from_candidate 返回的配置
%   viewMode - '3d' 或 'top'

if nargin < 4 || isempty(viewMode)
    viewMode = '3d';
end

cla(ax);
hold(ax,'on');

%% 1. 绘制降采样地形（仅降低绘图密度，不改变评价数据）
x = env.terrain.x;
y = env.terrain.y;
Z = env.terrain.Z;

step = max(1,ceil(max(size(Z))/cfg.environment.previewMaxGrid));
xs = x(1:step:end);
ys = y(1:step:end);
Zs = Z(1:step:end,1:step:end);

surf(ax,xs,ys,Zs, ...
    'EdgeColor','none', ...
    'FaceAlpha',0.95);

%% 2. 起点、终点与环境附加层
plot3(ax,env.start(1),env.start(2),env.start(3), ...
    'go','MarkerFaceColor','g','MarkerSize',7);
plot3(ax,env.goal(1),env.goal(2),env.goal(3), ...
    'rs','MarkerFaceColor','r','MarkerSize',7);

for k = 1:numel(env.staticObstacles)
    draw_cylinder(ax,env.staticObstacles(k));
end

if ~strcmpi(env.wind.type,'constant') || norm(env.wind.constant) > 0
    draw_wind_sparse(ax,env,cfg);
end

for k = 1:numel(env.dynamicObstacles)
    draw_dynamic_clipped(ax,env.dynamicObstacles(k),env);
end

showGuides = true;
if isfield(cfg,'environment') && isfield(cfg.environment,'showGuideRoutes')
    showGuides = logical(cfg.environment.showGuideRoutes);
end
if env.scenarioId == 2 && showGuides
    draw_route_guides(ax,env);
end

%% 3. 坐标轴外观
xlabel(ax,'X / m');
ylabel(ax,'Y / m');
zlabel(ax,'Z / m');
grid(ax,'on');
box(ax,'on');
set(ax,'Clipping','on');

displayId = env.id;
if isfield(env,'candidateId') && ~isempty(env.candidateId)
    displayId = sprintf('%s (%s)',env.id,env.candidateId);
end
title(ax,sprintf('%s  |  relief %.0f m', ...
    displayId,max(Z(:))-min(Z(:))),'Interpreter','none');

% 不再使用 axis tight。axis tight 会把风箭头和动态障碍预测轨迹
% 一并纳入范围，从而使地形偏离画面中心。
xSpan = diff(env.xLim);
ySpan = diff(env.yLim);
zSpan = diff(env.zLim);

xPad = 0.025*xSpan;
yPad = 0.025*ySpan;
zPad = 0.035*max(zSpan,1);

xlim(ax,[env.xLim(1)-xPad, env.xLim(2)+xPad]);
ylim(ax,[env.yLim(1)-yPad, env.yLim(2)+yPad]);
zlim(ax,[env.zLim(1)-zPad, env.zLim(2)+zPad]);

% 固定为手动范围，后续叠加算法路径时不会再次被箭头或轨迹撑大。
set(ax,'XLimMode','manual','YLimMode','manual','ZLimMode','manual');

if strcmpi(viewMode,'top')
    view(ax,2);
    axis(ax,'equal');
else
    view(ax,43,31);
    axis(ax,'vis3d');

    % 将相机观察中心锁定到环境几何中心。
    camtarget(ax,[mean(env.xLim),mean(env.yLim),mean(env.zLim)]);

    % 统一画框比例，使真实地形在图中更居中且不过度扁平。
    pbaspect(ax,[1.15,1.00,0.72]);
end
end

function draw_cylinder(ax,o)
[xx,yy,zz] = cylinder(o.radius,24);
zz = o.zMin + (o.zMax-o.zMin)*zz;
surf(ax,xx+o.center(1),yy+o.center(2),zz, ...
    'FaceAlpha',0.22, ...
    'EdgeColor','none', ...
    'FaceColor',[0.45 0.20 0.65]);
end

function draw_wind_sparse(ax,env,cfg)
%DRAW_WIND_SPARSE 仅用于显示的稀疏风场，不影响 wind_velocity 评价。

% 原版默认 7×6=42 个箭头。这里最多显示 4×3=12 个。
requestedGrid = cfg.environment.previewWindGrid;
nx = max(2,min(requestedGrid(1),4));
ny = max(2,min(requestedGrid(2),3));

[xg,yg] = meshgrid( ...
    linspace(env.xLim(1),env.xLim(2),nx), ...
    linspace(env.yLim(1),env.yLim(2),ny));

h = interp2(env.terrain.x,env.terrain.y,env.terrain.Z, ...
    xg,yg,'linear');

% 将箭头放在距地形约 25% 可用高度处，减少与路径的重叠。
zg = h + 0.25*(env.zLim(2)-h);
P = [xg(:),yg(:),zg(:)];
W = wind_velocity(env,P,0);

valid = all(isfinite(P),2) & all(isfinite(W),2) & ...
    vecnorm(W,2,2) > 1e-10;
P = P(valid,:);
W = W(valid,:);

if isempty(P)
    return;
end

% 注意：原版第五个缩放参数是 65，会生成非常长的箭头。
% 0.70 表示使用 MATLAB 自动缩放后的 70%，仅影响图形显示。
quiver3(ax,P(:,1),P(:,2),P(:,3), ...
    W(:,1),W(:,2),W(:,3),0.70, ...
    'Color',[0.18 0.18 0.18], ...
    'LineWidth',0.75, ...
    'MaxHeadSize',0.55);
end

function draw_dynamic_clipped(ax,o,env)
%DRAW_DYNAMIC_CLIPPED 只绘制位于地图范围内的预测轨迹。
t = linspace(0,90,28)';
P = o.p0 + t.*o.velocity;

inside = P(:,1) >= env.xLim(1) & P(:,1) <= env.xLim(2) & ...
         P(:,2) >= env.yLim(1) & P(:,2) <= env.yLim(2) & ...
         P(:,3) >= env.zLim(1) & P(:,3) <= env.zLim(2);

Pinside = P(inside,:);
if size(Pinside,1) >= 2
    plot3(ax,Pinside(:,1),Pinside(:,2),Pinside(:,3), ...
        '--','LineWidth',1.1);
end

% 初始位置在地图内时才绘制标记。
if o.p0(1) >= env.xLim(1) && o.p0(1) <= env.xLim(2) && ...
   o.p0(2) >= env.yLim(1) && o.p0(2) <= env.yLim(2) && ...
   o.p0(3) >= env.zLim(1) && o.p0(3) <= env.zLim(2)
    plot3(ax,o.p0(1),o.p0(2),o.p0(3), ...
        'ko','MarkerFaceColor','y','MarkerSize',5);
end
end

function draw_route_guides(ax,env)
G = candidate_guide_routes(env.meta.catalogItem.recipe);
for k = 1:numel(G)
    p = G{k};
    x = env.xLim(1) + p(:,1)*diff(env.xLim);
    y = env.yLim(1) + p(:,2)*diff(env.yLim);
    z = interp2(env.terrain.x,env.terrain.y,env.terrain.Z, ...
        x,y,'linear') + 8;
    plot3(ax,x,y,z,'w--','LineWidth',1.0);
end
end
