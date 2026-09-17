function pathRC = astar_grid(costMap,startRC,goalRC,maxExpansions)
%ASTAR_GRID 基础 8 邻域 A*，用于粗粒度种子生成。
%
% costMap 为 ny×nx 正代价，Inf 表示不可通行。输出 pathRC 每行为 [row,col]。
% 该实现强调透明和可复现，不使用第三方工具箱。

% [逐行说明] 计算或更新 `[ny,nx]`，供后续算法、评价或日志步骤使用。
[ny,nx]=size(costMap);
% [逐行说明] 计算或更新 `startRC`，供后续算法、评价或日志步骤使用。
startRC=round(startRC); goalRC=round(goalRC);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if any(startRC<1)||startRC(1)>ny||startRC(2)>nx|| ...
   any(goalRC<1)||goalRC(1)>ny||goalRC(2)>nx|| ...
   ~isfinite(costMap(startRC(1),startRC(2)))||~isfinite(costMap(goalRC(1),goalRC(2)))
    % [逐行说明] 计算或更新 `pathRC`，供后续算法、评价或日志步骤使用。
    pathRC=[]; return;
end
% [逐行说明] 计算或更新 `n`，供后续算法、评价或日志步骤使用。
n=ny*nx;
% [逐行说明] 计算或更新 `g`，供后续算法、评价或日志步骤使用。
g=inf(n,1); f=inf(n,1); parent=zeros(n,1,'uint32');
% [逐行说明] 计算或更新 `open`，供后续算法、评价或日志步骤使用。
open=false(n,1); closed=false(n,1);
% [逐行说明] 计算或更新 `sIdx`，供后续算法、评价或日志步骤使用。
sIdx=sub2ind([ny,nx],startRC(1),startRC(2));
% [逐行说明] 计算或更新 `gIdx`，供后续算法、评价或日志步骤使用。
gIdx=sub2ind([ny,nx],goalRC(1),goalRC(2));
% [逐行说明] 计算或更新 `g(sIdx)`，供后续算法、评价或日志步骤使用。
g(sIdx)=0; f(sIdx)=heuristic(startRC,goalRC); open(sIdx)=true;
% [逐行说明] 计算或更新 `steps`，供后续算法、评价或日志步骤使用。
steps=[-1 -1;-1 0;-1 1;0 -1;0 1;1 -1;1 0;1 1];
% [逐行说明] 计算或更新 `expansions`，供后续算法、评价或日志步骤使用。
expansions=0;

% [逐行说明] 在循环条件保持成立期间重复执行后续语句。
while any(open)
    % [逐行说明] 计算或更新 `openIdx`，供后续算法、评价或日志步骤使用。
    openIdx=find(open);
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    [~,loc]=min(f(openIdx));
    % [逐行说明] 计算或更新 `current`，供后续算法、评价或日志步骤使用。
    current=openIdx(loc);
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if current==gIdx, break; end
    % [逐行说明] 计算或更新 `open(current)`，供后续算法、评价或日志步骤使用。
    open(current)=false; closed(current)=true;
    % [逐行说明] 计算或更新 `expansions`，供后续算法、评价或日志步骤使用。
    expansions=expansions+1;
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if expansions>maxExpansions, pathRC=[]; return; end
    % [逐行说明] 计算或更新 `[r,c]`，供后续算法、评价或日志步骤使用。
    [r,c]=ind2sub([ny,nx],current);
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for k=1:8
        % [逐行说明] 计算或更新 `rr`，供后续算法、评价或日志步骤使用。
        rr=r+steps(k,1); cc=c+steps(k,2);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if rr<1||rr>ny||cc<1||cc>nx, continue; end
        % [逐行说明] 计算或更新 `ni`，供后续算法、评价或日志步骤使用。
        ni=sub2ind([ny,nx],rr,cc);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if closed(ni)||~isfinite(costMap(rr,cc)), continue; end
        % [逐行说明] 计算或更新 `move`，供后续算法、评价或日志步骤使用。
        move=hypot(steps(k,1),steps(k,2));
        % [逐行说明] 计算或更新 `tentative`，供后续算法、评价或日志步骤使用。
        tentative=g(current)+move*0.5*(costMap(r,c)+costMap(rr,cc));
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if tentative<g(ni)
            % [逐行说明] 计算或更新 `parent(ni)`，供后续算法、评价或日志步骤使用。
            parent(ni)=uint32(current);
            % [逐行说明] 计算或更新 `g(ni)`，供后续算法、评价或日志步骤使用。
            g(ni)=tentative;
            % [逐行说明] 计算或更新 `f(ni)`，供后续算法、评价或日志步骤使用。
            f(ni)=tentative+heuristic([rr,cc],goalRC);
            % [逐行说明] 计算或更新 `open(ni)`，供后续算法、评价或日志步骤使用。
            open(ni)=true;
        end
    end
end

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfinite(g(gIdx))
    % [逐行说明] 计算或更新 `pathRC`，供后续算法、评价或日志步骤使用。
    pathRC=[]; return;
end
% [逐行说明] 计算或更新 `idx`，供后续算法、评价或日志步骤使用。
idx=gIdx; rev=zeros(n,1,'uint32'); count=0;
% [逐行说明] 在循环条件保持成立期间重复执行后续语句。
while idx~=0
    % [逐行说明] 计算或更新 `count`，供后续算法、评价或日志步骤使用。
    count=count+1; rev(count)=uint32(idx);
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if idx==sIdx, break; end
    % [逐行说明] 计算或更新 `idx`，供后续算法、评价或日志步骤使用。
    idx=double(parent(idx));
end
% [逐行说明] 计算或更新 `rev`，供后续算法、评价或日志步骤使用。
rev=double(rev(count:-1:1));
% [逐行说明] 计算或更新 `[r,c]`，供后续算法、评价或日志步骤使用。
[r,c]=ind2sub([ny,nx],rev);
% [逐行说明] 计算或更新 `pathRC`，供后续算法、评价或日志步骤使用。
pathRC=[r(:),c(:)];
end

function h=heuristic(a,b)
% [逐行说明] 计算或更新 `h`，供后续算法、评价或日志步骤使用。
h=hypot(a(1)-b(1),a(2)-b(2));
end
