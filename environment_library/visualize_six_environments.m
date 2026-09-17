function environments = visualize_six_environments(userCfg)
%VISUALIZE_SIX_ENVIRONMENTS 一次性展示论文六种环境，不运行任何优化算法。
%
% 使用方法
% -------------------------------------------------------------------------
%   startup;
%   visualize_six_environments;
%
% 输出 environments 为 1×6 cell，可继续检查 env.terrain、风场或障碍数据。
% 绘图时为了降低显存占用，最多抽取约 220×220 个网格点；该抽取仅作用于
% 图形显示，返回的环境和正式评价器仍保留完整原始栅格。

if nargin<1 || isempty(userCfg), userCfg=default_config(); end
cfg=merge_structs(default_config(),userCfg);
environments=cell(1,6);
for sid=1:6
    environments{sid}=build_scenario_environment(cfg,sid,100000+sid*1000);
end

figure('Name','TAAS-FPO 六类实验环境','Color','w');
layout=tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
title(layout,'六类冻结实验环境：S1-S2 合成，S3-S6 公开真实 DEM');
for sid=1:6
    nexttile;
    plot_environment(environments{sid},cfg);
end
end

function plot_environment(env,cfg)
% 仅对显示网格降采样，完整 DEM 不被修改。
stepX=max(1,ceil(numel(env.terrain.x)/220));
stepY=max(1,ceil(numel(env.terrain.y)/220));
x=env.terrain.x(1:stepX:end);
y=env.terrain.y(1:stepY:end);
Z=env.terrain.Z(1:stepY:end,1:stepX:end);
[X,Y]=meshgrid(x,y);
surf(X,Y,Z,'EdgeColor','none','FaceAlpha',0.93);
hold on;
colormap(gca,parula);

% 绘制固定起点和终点。高度为真实地形/合成地形加最小净空和固定裕度。
plot3(env.start(1),env.start(2),env.start(3),'go', ...
    'MarkerFaceColor','g','MarkerSize',7);
plot3(env.goal(1),env.goal(2),env.goal(3),'rs', ...
    'MarkerFaceColor','r','MarkerSize',7);
plot3([env.start(1),env.goal(1)],[env.start(2),env.goal(2)], ...
    [env.start(3),env.goal(3)],'k:','LineWidth',1.0);

% 静态圆柱是独立禁飞层，不会写入或抬高 DEM。
for q=1:numel(env.staticObstacles)
    o=env.staticObstacles(q);
    if strcmpi(o.type,'cylinder')
        [cx,cy,cz]=cylinder(o.radius,24);
        cz=o.zMin+(o.zMax-o.zMin)*cz;
        surf(cx+o.center(1),cy+o.center(2),cz, ...
            'EdgeColor','none','FaceAlpha',0.30);
    end
end

% 用直线飞行时间作为展示窗口，画出动态障碍的确定性预测轨迹。
nominalTime=norm(env.goal-env.start)/cfg.uav.groundSpeed;
for m=1:numel(env.dynamicObstacles)
    o=env.dynamicObstacles(m);
    t=linspace(0,nominalTime,60)';
    O=o.p0+t.*o.velocity;
    plot3(O(:,1),O(:,2),O(:,3),'m--','LineWidth',1.3);
    plot3(O(1,1),O(1,2),O(1,3),'mo','MarkerFaceColor','m','MarkerSize',5);
end

% S5/S6 额外显示稀疏水平风矢量。箭头仅用于理解风场，不参与评价。
if ~strcmpi(env.wind.type,'constant') || norm(env.wind.constant)>0
    gx=linspace(env.xLim(1)+0.1*diff(env.xLim),env.xLim(2)-0.1*diff(env.xLim),7);
    gy=linspace(env.yLim(1)+0.1*diff(env.yLim),env.yLim(2)-0.1*diff(env.yLim),7);
    [WX,WY]=meshgrid(gx,gy);
    queryXY=[WX(:),WY(:)];
    terrainZ=terrain_height(env,queryXY(:,1),queryXY(:,2));
    queryP=[queryXY,terrainZ(:)+cfg.constraint.clearance+80];
    W=wind_velocity(env,queryP,zeros(size(queryP,1),1));
    quiver3(queryP(:,1),queryP(:,2),queryP(:,3),W(:,1),W(:,2),W(:,3), ...
        30,'LineWidth',0.8,'Color',[0.1 0.1 0.1]);
end

xlabel('局部 X / m'); ylabel('局部 Y / m'); zlabel('高程 Z / m');
if env.meta.isRealDEM
    dataType='真实 DEM';
else
    dataType='合成地形';
end
title(sprintf('%s  %s\n%s',env.id,env.scenarioName,dataType),'Interpreter','none');
axis tight; grid on; view(42,31);
end
