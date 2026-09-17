function out = static_obstacle_check(P, env, cfg)
%STATIC_OBSTACLE_CHECK 连续检查轨迹线段与静态障碍的安全距离。
%
% 当前完整实现支持有限竖直圆柱。添加其他障碍类型时，应在此函数中保持
% 同一输出结构，不能在优化器内部写场景特例。

% [逐行说明] 计算或更新 `out`，供后续算法、评价或日志步骤使用。
out = struct('maxDeficit',0,'minDistance',inf,'worstObstacle',0, ...
    'worstSegment',0,'worstPoint',[NaN NaN NaN],'nearestObstaclePoint',[NaN NaN NaN]);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(env.staticObstacles)
    % [逐行说明] 结束当前函数并把已计算结果返回调用方。
    return;
end
% [逐行说明] 计算或更新 `safetyExtra`，供后续算法、评价或日志步骤使用。
safetyExtra = cfg.uav.radius+cfg.constraint.staticSafety;

% [逐行说明] 开始按给定索引范围逐项执行循环。
for q = 1:numel(env.staticObstacles)
    % [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
    o = env.staticObstacles(q);
    % [逐行说明] 根据当前变量值选择对应处理分支。
    switch lower(o.type)
        % [逐行说明] 处理当前 switch 对应的取值分支。
        case 'cylinder'
            % [逐行说明] 计算或更新 `expanded`，供后续算法、评价或日志步骤使用。
            expanded = o.radius+safetyExtra;
            % [逐行说明] 开始按给定索引范围逐项执行循环。
            for j = 1:size(P,1)-1
                % [逐行说明] 计算或更新 `A`，供后续算法、评价或日志步骤使用。
                A=P(j,:); B=P(j+1,:);
                % 廉价包围盒预筛选。只有可能靠近圆柱时才执行 fminbnd。
                if max(A(1),B(1)) < o.center(1)-expanded || min(A(1),B(1)) > o.center(1)+expanded || ...
                   max(A(2),B(2)) < o.center(2)-expanded || min(A(2),B(2)) > o.center(2)+expanded || ...
                   max(A(3),B(3)) < o.zMin-safetyExtra || min(A(3),B(3)) > o.zMax+safetyExtra
                    % [逐行说明] 跳过本轮剩余语句并进入下一轮循环。
                    continue;
                end
                % [逐行说明] 计算或更新 `[d,t,npt]`，供后续算法、评价或日志步骤使用。
                [d,t,npt] = segment_cylinder_min_distance(A,B,o);
                % [逐行说明] 计算或更新 `out.minDistance`，供后续算法、评价或日志步骤使用。
                out.minDistance = min(out.minDistance,d);
                % [逐行说明] 计算或更新 `deficit`，供后续算法、评价或日志步骤使用。
                deficit = max(0,safetyExtra-d);
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if deficit > out.maxDeficit
                    % [逐行说明] 计算或更新 `out.maxDeficit`，供后续算法、评价或日志步骤使用。
                    out.maxDeficit=deficit;
                    % [逐行说明] 计算或更新 `out.worstObstacle`，供后续算法、评价或日志步骤使用。
                    out.worstObstacle=q;
                    % [逐行说明] 计算或更新 `out.worstSegment`，供后续算法、评价或日志步骤使用。
                    out.worstSegment=j;
                    % [逐行说明] 计算或更新 `out.worstPoint`，供后续算法、评价或日志步骤使用。
                    out.worstPoint=A+t*(B-A);
                    % [逐行说明] 计算或更新 `out.nearestObstaclePoint`，供后续算法、评价或日志步骤使用。
                    out.nearestObstaclePoint=npt;
                end
            end
        % [逐行说明] 处理 switch 中未显式列出的其他取值。
        otherwise
            % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
            error('static_obstacle_check:UnknownType','Unsupported obstacle type: %s',o.type);
    end
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isinf(out.minDistance)
    % 没有通过包围盒预筛选的障碍，仍用采样点给出一个保守最小距离估计，
    % 便于风险模型和结果展示。
    for q=1:numel(env.staticObstacles)
        % [逐行说明] 计算或更新 `o`，供后续算法、评价或日志步骤使用。
        o=env.staticObstacles(q);
        % [逐行说明] 计算或更新 `dxy`，供后续算法、评价或日志步骤使用。
        dxy=hypot(P(:,1)-o.center(1),P(:,2)-o.center(2))-o.radius;
        % [逐行说明] 计算或更新 `dz`，供后续算法、评价或日志步骤使用。
        dz=max([o.zMin-P(:,3),P(:,3)-o.zMax,zeros(size(P,1),1)],[],2);
        % [逐行说明] 计算或更新 `out.minDistance`，供后续算法、评价或日志步骤使用。
        out.minDistance=min(out.minDistance,min(hypot(max(dxy,0),dz)));
    end
end
end
