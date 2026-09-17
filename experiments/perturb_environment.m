function env2 = perturb_environment(env,mode,level,seed)
%PERTURB_ENVIRONMENT 在每次运行开始前生成固定鲁棒性扰动。
%
% 扰动只生成一次并写入 env2，evaluate_path 中不会每次重新抽样，避免同一
% 候选在重复评价时得到不同目标值。

% [逐行说明] 计算或更新 `state`，供后续算法、评价或日志步骤使用。
state=rng;cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
% [逐行说明] 计算或更新 `rng(seed,'twister');env2`，供后续算法、评价或日志步骤使用。
rng(seed,'twister');env2=env;
% [逐行说明] 根据当前变量值选择对应处理分支。
switch lower(mode)
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case 'dem_noise'
        % [逐行说明] 计算或更新 `noise`，供后续算法、评价或日志步骤使用。
        noise=level*randn(size(env.terrain.Z));
        % 使用小窗口平滑模拟空间相关误差，而非独立像元白噪声。
        kernel=ones(5)/25;noise=conv2(noise,kernel,'same');
        % [逐行说明] 计算或更新 `env2.terrain.Z`，供后续算法、评价或日志步骤使用。
        env2.terrain.Z=env.terrain.Z+noise;
        % [逐行说明] 计算或更新 `env2.meta.robustness`，供后续算法、评价或日志步骤使用。
        env2.meta.robustness=struct('mode',mode,'level',level,'seed',seed);
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case 'wind_scale'
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if strcmpi(env.wind.type,'constant')
            % [逐行说明] 计算或更新 `env2.wind.constant`，供后续算法、评价或日志步骤使用。
            env2.wind.constant=env.wind.constant*level;
        % [逐行说明] 处理前述条件均不成立的情况。
        else
            % [逐行说明] 计算或更新 `env2.wind.base`，供后续算法、评价或日志步骤使用。
            env2.wind.base=env.wind.base*level;
            % [逐行说明] 计算或更新 `env2.wind.vortexStrength`，供后续算法、评价或日志步骤使用。
            env2.wind.vortexStrength=env.wind.vortexStrength*level;
        end
        % [逐行说明] 计算或更新 `env2.meta.robustness`，供后续算法、评价或日志步骤使用。
        env2.meta.robustness=struct('mode',mode,'level',level,'seed',seed);
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case 'wind_direction_deg'
        % [逐行说明] 计算或更新 `ang`，供后续算法、评价或日志步骤使用。
        ang=deg2rad(level)*(2*rand-1);R=[cos(ang),-sin(ang);sin(ang),cos(ang)];
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if strcmpi(env.wind.type,'constant')
            % [逐行说明] 计算或更新 `env2.wind.constant(1:2)`，供后续算法、评价或日志步骤使用。
            env2.wind.constant(1:2)=(R*env.wind.constant(1:2)')';
        % [逐行说明] 处理前述条件均不成立的情况。
        else
            % [逐行说明] 计算或更新 `env2.wind.base(1:2)`，供后续算法、评价或日志步骤使用。
            env2.wind.base(1:2)=(R*env.wind.base(1:2)')';
        end
        % [逐行说明] 计算或更新 `env2.meta.robustness`，供后续算法、评价或日志步骤使用。
        env2.meta.robustness=struct('mode',mode,'level',level,'actualAngle',ang,'seed',seed);
    % [逐行说明] 处理当前 switch 对应的取值分支。
    case 'dynamic_noise'
        % [逐行说明] 开始按给定索引范围逐项执行循环。
        for m=1:numel(env2.dynamicObstacles)
            % [逐行说明] 计算或更新 `env2.dynamicObstacles(m).p0`，供后续算法、评价或日志步骤使用。
            env2.dynamicObstacles(m).p0=env2.dynamicObstacles(m).p0+level*randn(1,3);
            % [逐行说明] 计算或更新 `env2.dynamicObstacles(m).velocity`，供后续算法、评价或日志步骤使用。
            env2.dynamicObstacles(m).velocity=env2.dynamicObstacles(m).velocity+0.1*level*randn(1,3);
        end
        % [逐行说明] 计算或更新 `env2.meta.robustness`，供后续算法、评价或日志步骤使用。
        env2.meta.robustness=struct('mode',mode,'level',level,'seed',seed);
    % [逐行说明] 处理 switch 中未显式列出的其他取值。
    otherwise
        % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
        error('perturb_environment:Mode','Unknown perturbation mode: %s',mode);
end
end
