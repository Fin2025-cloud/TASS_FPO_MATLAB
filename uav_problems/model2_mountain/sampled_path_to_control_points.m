function controlPoints = sampled_path_to_control_points(P,env,cfg)
%SAMPLED_PATH_TO_CONTROL_POINTS 将已有三维轨迹按弧长压缩为 K+2 个控制点。
% 用于滚动重规划热启动，保留旧路径高度信息。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if size(P,1)<2,P=[env.start;env.goal];end
% [逐行说明] 计算或更新 `s`，供后续算法、评价或日志步骤使用。
s=[0;cumsum(vecnorm(diff(P,1,1),2,2))];
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if s(end)<=eps
    % [逐行说明] 计算或更新 `t`，供后续算法、评价或日志步骤使用。
    t=linspace(0,1,cfg.path.K+2)';controlPoints=env.start.*(1-t)+env.goal.*t;
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `q`，供后续算法、评价或日志步骤使用。
    q=linspace(0,s(end),cfg.path.K+2)';
    % [逐行说明] 计算或更新 `controlPoints`，供后续算法、评价或日志步骤使用。
    controlPoints=[interp1(s,P(:,1),q),interp1(s,P(:,2),q),interp1(s,P(:,3),q)];
end
% [逐行说明] 计算或更新 `controlPoints(1,:)`，供后续算法、评价或日志步骤使用。
controlPoints(1,:)=env.start;controlPoints(end,:)=env.goal;
end
