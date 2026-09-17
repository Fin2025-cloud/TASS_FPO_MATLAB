function h = plot_path_3d(env,result,cfg)
%PLOT_PATH_3D 绘制 DEM、静态障碍、动态障碍和最优三维轨迹。
%
% 本函数只读取已保存结果，不重新运行算法，也不修改实验数据。

% [逐行说明] 计算或更新 `[X,Y]`，供后续算法、评价或日志步骤使用。
[X,Y]=meshgrid(env.terrain.x,env.terrain.y);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
surf(X,Y,env.terrain.Z,'EdgeColor','none','FaceAlpha',0.88);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
hold on;
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
colormap parula;

% 静态圆柱障碍。
for q=1:numel(env.staticObstacles)
    % [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
    o=env.staticObstacles(q);
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if strcmpi(o.type,'cylinder')
        % [逐行说明] 计算或更新 `[cx,cy,cz]`，供后续算法、评价或日志步骤使用。
        [cx,cy,cz]=cylinder(o.radius,32);
        % [逐行说明] 计算或更新 `cz`，供后续算法、评价或日志步骤使用。
        cz=o.zMin+(o.zMax-o.zMin)*cz;
        % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
        surf(cx+o.center(1),cy+o.center(2),cz,'EdgeColor','none','FaceAlpha',0.35);
    end
end

% 动态障碍显示其在最优轨迹时间范围内的预测运动线。
if isfield(result,'arrivalTime') && ~isempty(result.arrivalTime)
    % [逐行说明] 计算或更新 `tf`，供后续算法、评价或日志步骤使用。
    tf=result.arrivalTime(end);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `tf`，供后续算法、评价或日志步骤使用。
    tf=0;
end
% [逐行说明] 开始按给定索引范围逐项执行循环。
for m=1:numel(env.dynamicObstacles)
    % [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
    o=env.dynamicObstacles(m);
    % [逐行说明] 计算或更新 `tt`，供后续算法、评价或日志步骤使用。
    tt=linspace(0,tf,80)';
    % [逐行说明] 计算或更新 `O`，供后续算法、评价或日志步骤使用。
    O=o.p0+tt.*o.velocity;
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    plot3(O(:,1),O(:,2),O(:,3),'--','LineWidth',1.2);
end

% [逐行说明] 计算或更新 `P`，供后续算法、评价或日志步骤使用。
P=result.pathSamples;
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
plot3(P(:,1),P(:,2),P(:,3),'k-','LineWidth',2.2);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isfield(result,'controlPoints') && ~isempty(result.controlPoints)
    % [逐行说明] 计算或更新 `C`，供后续算法、评价或日志步骤使用。
    C=result.controlPoints;
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    plot3(C(:,1),C(:,2),C(:,3),'ko-','LineWidth',1.0,'MarkerSize',4,'MarkerFaceColor','w');
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
plot3(env.start(1),env.start(2),env.start(3),'o','MarkerSize',9,'MarkerFaceColor','g');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
plot3(env.goal(1),env.goal(2),env.goal(3),'s','MarkerSize',9,'MarkerFaceColor','r');

% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
xlabel('X / m');ylabel('Y / m');zlabel('Z / m');
% [逐行说明] 计算或更新 `title(sprintf('%s | feasible`，供后续算法、评价或日志步骤使用。
title(sprintf('%s | feasible=%d, F=%.4g, CV=%.3g',env.scenarioName,result.isFeasible,result.F,result.CV));
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
grid on;axis tight;view(43,31);
% [逐行说明] 计算或更新 `h`，供后续算法、评价或日志步骤使用。
h=gca;

% 在标题之外显示关键安全指标，避免只展示“看起来合理”的轨迹。
textStr=sprintf('L=%.1fm  E=%.1fJ  min clearance=%.1fm\nmax climb=%.1fdeg  max curvature=%.4f  model=%s', ...
    result.cost.length,result.cost.energy,result.minClearance,rad2deg(result.maxClimbAngle), ...
    result.maxCurvature,cfg.energy.model);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
annotation('textbox',[0.13 0.01 0.75 0.08],'String',textStr,'EdgeColor','none','HorizontalAlignment','center');
end
