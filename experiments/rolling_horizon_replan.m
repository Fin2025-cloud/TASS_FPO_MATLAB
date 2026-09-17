function mission = rolling_horizon_replan(env,cfg,numEpisodes,executeFraction)
%ROLLING_HORIZON_REPLAN 准动态滚动重规划增强实验。
%
% 每轮：更新当前位置与动态障碍预测 -> 上一条剩余路径热启动 -> 运行有限
% MaxFEs -> 执行前 executeFraction。函数报告每轮规划时间和是否超出假定周期。
% 主模型仍固定地速，不添加隐式等待变量。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<3||isempty(numEpisodes),numEpisodes=5;end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<4||isempty(executeFraction),executeFraction=0.20;end
% [逐行说明] 计算或更新 `mission`，供后续算法、评价或日志步骤使用。
mission=struct('episodes',struct([]),'executedPath',env.start,'completed',false,'totalMissionTime',0);
% [逐行说明] 计算或更新 `currentEnv`，供后续算法、评价或日志步骤使用。
currentEnv=env;warmZ=[];absoluteTime=0;
% [逐行说明] 开始按给定索引范围逐项执行循环。
for ep=1:numEpisodes
    % [逐行说明] 计算或更新 `problem`，供后续算法、评价或日志步骤使用。
    problem=make_problem(currentEnv,cfg);
    % [逐行说明] 计算或更新 `baseInitializer`，供后续算法、评价或日志步骤使用。
    baseInitializer=problem.initializer;
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if ~isempty(warmZ)
        % [逐行说明] 计算或更新 `problem.initializer`，供后续算法、评价或日志步骤使用。
        problem.initializer=@warm_initializer;
    end
    % [逐行说明] 计算或更新 `local`，供后续算法、评价或日志步骤使用。
    local=cfg;local.algorithm.seed=cfg.algorithm.seed+ep-1;
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    [~,~,~,out]=TAAS_FPO(problem,local);
    % [逐行说明] 计算或更新 `result`，供后续算法、评价或日志步骤使用。
    result=out.bestResult;
    % [逐行说明] 计算或更新 `episode`，供后续算法、评价或日志步骤使用。
    episode=struct('index',ep,'start',currentEnv.start,'result',result,'runtime',out.runtime, ...
        'FEs',out.actualFEs,'absoluteStartTime',absoluteTime);
    % [逐行说明] 计算或更新 `mission.episodes`，供后续算法、评价或日志步骤使用。
    mission.episodes=[mission.episodes;episode]; %#ok<AGROW>
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if ~result.isFeasible,break;end
    % [逐行说明] 计算或更新 `P`，供后续算法、评价或日志步骤使用。
    P=result.pathSamples;T=result.arrivalTime;
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if ep==numEpisodes||norm(currentEnv.goal-currentEnv.start)<20
        % [逐行说明] 计算或更新 `executeIdx`，供后续算法、评价或日志步骤使用。
        executeIdx=size(P,1);
    % [逐行说明] 处理前述条件均不成立的情况。
    else
        % [逐行说明] 计算或更新 `executeIdx`，供后续算法、评价或日志步骤使用。
        executeIdx=max(2,min(size(P,1),round(executeFraction*size(P,1))));
    end
    % [逐行说明] 计算或更新 `mission.executedPath`，供后续算法、评价或日志步骤使用。
    mission.executedPath=[mission.executedPath;P(2:executeIdx,:)]; %#ok<AGROW>
    % [逐行说明] 计算或更新 `dt`，供后续算法、评价或日志步骤使用。
    dt=T(executeIdx);absoluteTime=absoluteTime+dt;
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if executeIdx==size(P,1)
        % [逐行说明] 计算或更新 `mission.completed`，供后续算法、评价或日志步骤使用。
        mission.completed=true;break;
    end
    % [逐行说明] 计算或更新 `remaining`，供后续算法、评价或日志步骤使用。
    remaining=P(executeIdx:end,:);
    % [逐行说明] 计算或更新 `currentEnv.start`，供后续算法、评价或日志步骤使用。
    currentEnv.start=P(executeIdx,:);
    % 将动态障碍推进到当前绝对时刻，然后新规划局部时间重新从 0 开始。
    for m=1:numel(currentEnv.dynamicObstacles)
        % [逐行说明] 计算或更新 `currentEnv.dynamicObstacles(m).p0`，供后续算法、评价或日志步骤使用。
        currentEnv.dynamicObstacles(m).p0=currentEnv.dynamicObstacles(m).p0+ ...
            currentEnv.dynamicObstacles(m).velocity*dt;
    end
    % [逐行说明] 计算或更新 `cp`，供后续算法、评价或日志步骤使用。
    cp=sampled_path_to_control_points(remaining,currentEnv,cfg);
    % [逐行说明] 计算或更新 `warmZ`，供后续算法、评价或日志步骤使用。
    warmZ=reflect_bounds(encode_control_points(cp,cfg,problem.physicalLB,problem.physicalUB),0,1);
end
% [逐行说明] 计算或更新 `mission.totalMissionTime`，供后续算法、评价或日志步骤使用。
mission.totalMissionTime=absoluteTime;

    function [X,meta]=warm_initializer(N,isRestart)
        % [逐行说明] 计算或更新 `[X,meta]`，供后续算法、评价或日志步骤使用。
        [X,meta]=baseInitializer(N,isRestart);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if ~isRestart&&N>=1
            % [逐行说明] 计算或更新 `X(1,:)`，供后续算法、评价或日志步骤使用。
            X(1,:)=warmZ;meta.source(1)="rolling_warm_start";
            % [逐行说明] 计算或更新 `nLocal`，供后续算法、评价或日志步骤使用。
            nLocal=min(max(1,round(0.25*N)),N-1);
            % [逐行说明] 开始按给定索引范围逐项执行循环。
            for k=1:nLocal
                % [逐行说明] 计算或更新 `X(k+1,:)`，供后续算法、评价或日志步骤使用。
                X(k+1,:)=reflect_bounds(warmZ+0.03*randn(1,problem.dim),0,1);
                % [逐行说明] 计算或更新 `meta.source(k+1)`，供后续算法、评价或日志步骤使用。
                meta.source(k+1)="rolling_warm_neighbor";
            end
        end
    end
end
