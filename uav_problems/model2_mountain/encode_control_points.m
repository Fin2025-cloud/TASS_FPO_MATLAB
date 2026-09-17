function z = encode_control_points(controlPoints, cfg, physicalLB, physicalUB)
%ENCODE_CONTROL_POINTS 将完整控制点矩阵重新编码为归一化决策向量。
%
% controlPoints 第一行和最后一行是固定起终点，仅编码中间 K 行。

% [逐行说明] 计算或更新 `internal`，供后续算法、评价或日志步骤使用。
internal=controlPoints(2:end-1,:);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if size(internal,1)~=cfg.path.K || size(internal,2)~=3
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('encode_control_points:Size','Unexpected internal control point size.');
end
% [逐行说明] 计算或更新 `physical`，供后续算法、评价或日志步骤使用。
physical=reshape(internal',1,[]);
% [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
z=(physical-physicalLB)./(physicalUB-physicalLB+eps);
end
