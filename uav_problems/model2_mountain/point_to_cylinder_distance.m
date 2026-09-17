function [signedDistance, nearestPoint] = point_to_cylinder_distance(P, obstacle)
%POINT_TO_CYLINDER_DISTANCE 点到有限竖直圆柱的有符号距离。
%
% signedDistance > 0：点在圆柱外，到圆柱表面的最短距离；
% signedDistance = 0：点在表面；
% signedDistance < 0：点在圆柱内，绝对值近似为到最近边界的穿透深度。
%
% 使用有符号距离而不是“到实心集合的非负距离”非常重要：若轨迹进入障碍
% 内部，违反度必须随穿透深度增加，否则所有内部点都会得到相同的 0 距离。

% [逐行说明] 计算或更新 `c`，供后续算法、评价或日志步骤使用。
c = obstacle.center(:)';
% [逐行说明] 计算或更新 `r`，供后续算法、评价或日志步骤使用。
r = obstacle.radius;
% [逐行说明] 计算或更新 `zMin`，供后续算法、评价或日志步骤使用。
zMin = obstacle.zMin;
% [逐行说明] 计算或更新 `zMax`，供后续算法、评价或日志步骤使用。
zMax = obstacle.zMax;
% [逐行说明] 计算或更新 `zMid`，供后续算法、评价或日志步骤使用。
zMid = 0.5*(zMin+zMax);
% [逐行说明] 计算或更新 `halfH`，供后续算法、评价或日志步骤使用。
halfH = 0.5*(zMax-zMin);

% [逐行说明] 计算或更新 `qxy`，供后续算法、评价或日志步骤使用。
qxy = P(1:2)-c;
% [逐行说明] 计算或更新 `rho`，供后续算法、评价或日志步骤使用。
rho = norm(qxy);
% [逐行说明] 计算或更新 `d`，供后续算法、评价或日志步骤使用。
d = [rho-r, abs(P(3)-zMid)-halfH];
% [逐行说明] 计算或更新 `outside`，供后续算法、评价或日志步骤使用。
outside = norm(max(d,0));
% [逐行说明] 计算或更新 `inside`，供后续算法、评价或日志步骤使用。
inside = min(max(d),0);
% [逐行说明] 计算或更新 `signedDistance`，供后续算法、评价或日志步骤使用。
signedDistance = outside+inside;

% 最近表面点用于修复方向。区分圆柱内部与外部。
if rho > eps
    % [逐行说明] 计算或更新 `radialDir`，供后续算法、评价或日志步骤使用。
    radialDir=qxy/rho;
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `radialDir`，供后续算法、评价或日志步骤使用。
    radialDir=[1,0];
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if signedDistance < 0
    % [逐行说明] 计算或更新 `sideGap`，供后续算法、评价或日志步骤使用。
    sideGap=r-rho;
    % [逐行说明] 计算或更新 `topGap`，供后续算法、评价或日志步骤使用。
    topGap=zMax-P(3);
    % [逐行说明] 计算或更新 `bottomGap`，供后续算法、评价或日志步骤使用。
    bottomGap=P(3)-zMin;
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    [~,which]=min([sideGap,topGap,bottomGap]);
    % [逐行说明] 根据当前变量值选择对应处理分支。
    switch which
        % [逐行说明] 处理当前 switch 对应的取值分支。
        case 1
            % [逐行说明] 计算或更新 `nearestPoint`，供后续算法、评价或日志步骤使用。
            nearestPoint=[c+r*radialDir,P(3)];
        % [逐行说明] 处理当前 switch 对应的取值分支。
        case 2
            % [逐行说明] 计算或更新 `nearestPoint`，供后续算法、评价或日志步骤使用。
            nearestPoint=[P(1:2),zMax];
        % [逐行说明] 处理 switch 中未显式列出的其他取值。
        otherwise
            % [逐行说明] 计算或更新 `nearestPoint`，供后续算法、评价或日志步骤使用。
            nearestPoint=[P(1:2),zMin];
    end
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `nearestXY`，供后续算法、评价或日志步骤使用。
    nearestXY=c+radialDir*min(rho,r);
    % [逐行说明] 计算或更新 `nearestZ`，供后续算法、评价或日志步骤使用。
    nearestZ=min(max(P(3),zMin),zMax);
    % [逐行说明] 计算或更新 `nearestPoint`，供后续算法、评价或日志步骤使用。
    nearestPoint=[nearestXY,nearestZ];
end
end
