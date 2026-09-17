function out = dynamic_obstacle_check(P, time, env, cfg)
%DYNAMIC_OBSTACLE_CHECK 基于相对线性运动的区间连续最小距离。
%
% 在每个路径时间区间 [t_j,t_{j+1}] 内，假设 UAV 沿线段匀速运动，
% 动态障碍按给定恒速度运动。相对位置 r(t)=r0+v_rel*t 的最小距离可
% 解析求得，因此不会漏掉两个离散采样时刻之间的交叉碰撞。

% [逐行说明] 计算或更新 `out`，供后续算法、评价或日志步骤使用。
out = struct('maxDeficit',0,'minDistance',inf,'worstObstacle',0, ...
    'worstSegment',0,'worstTime',NaN,'worstPoint',[NaN NaN NaN], ...
    'obstaclePoint',[NaN NaN NaN]);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(env.dynamicObstacles)
    % [逐行说明] 结束当前函数并把已计算结果返回调用方。
    return;
end

% [逐行说明] 开始按给定索引范围逐项执行循环。
for m = 1:numel(env.dynamicObstacles)
    % [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
    o=env.dynamicObstacles(m);
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for j=1:size(P,1)-1
        % [逐行说明] 计算或更新 `dt`，供后续算法、评价或日志步骤使用。
        dt=time(j+1)-time(j);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if dt<=eps, continue; end
        % [逐行说明] 计算或更新 `vPath`，供后续算法、评价或日志步骤使用。
        vPath=(P(j+1,:)-P(j,:))/dt;
        % [逐行说明] 计算或更新 `obsAtStart`，供后续算法、评价或日志步骤使用。
        obsAtStart=o.p0+o.velocity*time(j);
        % [逐行说明] 计算或更新 `r0`，供后续算法、评价或日志步骤使用。
        r0=P(j,:)-obsAtStart;
        % [逐行说明] 计算或更新 `vRel`，供后续算法、评价或日志步骤使用。
        vRel=vPath-o.velocity;
        % [逐行说明] 计算或更新 `denom`，供后续算法、评价或日志步骤使用。
        denom=dot(vRel,vRel);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if denom<=eps
            % [逐行说明] 计算或更新 `tau`，供后续算法、评价或日志步骤使用。
            tau=0;
        % [逐行说明] 处理前述条件均不成立的情况。
        else
            % [逐行说明] 计算或更新 `tau`，供后续算法、评价或日志步骤使用。
            tau=min(max(-dot(r0,vRel)/denom,0),dt);
        end
        % [逐行说明] 计算或更新 `rel`，供后续算法、评价或日志步骤使用。
        rel=r0+vRel*tau;
        % [逐行说明] 计算或更新 `d`，供后续算法、评价或日志步骤使用。
        d=norm(rel);
        % [逐行说明] 计算或更新 `sigma`，供后续算法、评价或日志步骤使用。
        sigma=max([0,o.sigma0+o.sigmaRate*time(j),o.sigma0+o.sigmaRate*time(j+1)]);
        % [逐行说明] 计算或更新 `safe`，供后续算法、评价或日志步骤使用。
        safe=o.radius+cfg.uav.radius+cfg.constraint.dynamicSafety+cfg.constraint.robustEta*sigma;
        % [逐行说明] 计算或更新 `deficit`，供后续算法、评价或日志步骤使用。
        deficit=max(0,safe-d);
        % [逐行说明] 计算或更新 `out.minDistance`，供后续算法、评价或日志步骤使用。
        out.minDistance=min(out.minDistance,d-o.radius);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deficit>out.maxDeficit
            % [逐行说明] 计算或更新 `out.maxDeficit`，供后续算法、评价或日志步骤使用。
            out.maxDeficit=deficit;
            % [逐行说明] 计算或更新 `out.worstObstacle`，供后续算法、评价或日志步骤使用。
            out.worstObstacle=m;
            % [逐行说明] 计算或更新 `out.worstSegment`，供后续算法、评价或日志步骤使用。
            out.worstSegment=j;
            % [逐行说明] 计算或更新 `out.worstTime`，供后续算法、评价或日志步骤使用。
            out.worstTime=time(j)+tau;
            % [逐行说明] 计算或更新 `out.worstPoint`，供后续算法、评价或日志步骤使用。
            out.worstPoint=P(j,:)+vPath*tau;
            % [逐行说明] 计算或更新 `out.obstaclePoint`，供后续算法、评价或日志步骤使用。
            out.obstaclePoint=o.p0+o.velocity*out.worstTime;
        end
    end
end
end
