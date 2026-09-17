function [dmin, tmin, nearestCylinderPoint] = segment_cylinder_min_distance(A, B, obstacle)
%SEGMENT_CYLINDER_MIN_DISTANCE 线段到有限竖直圆柱的连续最小有符号距离。
%
% 点到凸圆柱的外部距离沿线段通常较平滑，但有符号距离在穿越边界时可能
% 出现分段结构。为避免单次全区间 fminbnd 的单峰假设造成漏检，先在 11 个
% 参数点粗扫，再只在最小粗采样点相邻区间内做有界精化，并显式检查端点。

% [逐行说明] 计算或更新 `coarseT`，供后续算法、评价或日志步骤使用。
coarseT=linspace(0,1,11);
% [逐行说明] 计算或更新 `coarseD`，供后续算法、评价或日志步骤使用。
coarseD=zeros(size(coarseT));
% [逐行说明] 开始按给定索引范围逐项执行循环。
for k=1:numel(coarseT)
    % [逐行说明] 计算或更新 `coarseD(k)`，供后续算法、评价或日志步骤使用。
    coarseD(k)=point_to_cylinder_distance(A+coarseT(k)*(B-A),obstacle);
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
[~,k0]=min(coarseD);
% [逐行说明] 计算或更新 `lo`，供后续算法、评价或日志步骤使用。
lo=coarseT(max(1,k0-1));
% [逐行说明] 计算或更新 `hi`，供后续算法、评价或日志步骤使用。
hi=coarseT(min(numel(coarseT),k0+1));
% [逐行说明] 计算或更新 `obj`，供后续算法、评价或日志步骤使用。
obj=@(t) point_to_cylinder_distance(A+t*(B-A),obstacle);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if hi-lo>eps
    % [逐行说明] 计算或更新 `opts`，供后续算法、评价或日志步骤使用。
    opts=optimset('TolX',1e-8,'Display','off');
    % [逐行说明] 计算或更新 `[tmin,dmin]`，供后续算法、评价或日志步骤使用。
    [tmin,dmin]=fminbnd(obj,lo,hi,opts);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `tmin`，供后续算法、评价或日志步骤使用。
    tmin=coarseT(k0);dmin=coarseD(k0);
end

% 将全部粗采样点和精化点比较，保证精化失败时仍不弱于粗扫。
[dCoarse,kc]=min(coarseD);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if dCoarse<dmin
    % [逐行说明] 计算或更新 `dmin`，供后续算法、评价或日志步骤使用。
    dmin=dCoarse;tmin=coarseT(kc);
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
[~,nearestCylinderPoint]=point_to_cylinder_distance(A+tmin*(B-A),obstacle);
end
