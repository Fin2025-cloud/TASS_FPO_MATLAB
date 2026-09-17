function results = run_cec_adapter(cecFunctionHandle,functionIds,dimensions,bounds,userCfg)
%RUN_CEC_ADAPTER 使用用户已验证的官方 CEC 函数执行 ASA-FPO 多次实验。
%
% 输入
% -------------------------------------------------------------------------
% cecFunctionHandle : 必须满足 value = handle(x,functionId)。x 为 1×D 行向量。
% functionIds       : 需要测试的官方函数编号，例如 1:10。
% dimensions        : 官方测试集允许的维度，例如 [10,20]。
% bounds            : [lowerBound,upperBound]，或由用户包装器自行处理。
% userCfg           : 配置结构。正式实验使用 cfg.experiment.numRuns>=30。
%
% 真实性约束
% -------------------------------------------------------------------------
% 1. 本项目不提供、复制或生成 CEC 的 C++、MEX、旋转矩阵和偏移数据；
% 2. CEC 中只运行 ASA-FPO 的通用归一化、策略学习与停滞恢复，TAI/CDR
%    由 ASA_FPO 强制关闭；
% 3. 每次运行保存独立种子和实际 FEs；不只保存最优的一次；
% 4. 用户必须先用官方文档给出的检查点验证 cecFunctionHandle。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<5||isempty(userCfg),userCfg=default_config();end
% [逐行说明] 计算或更新 `cfg`，供后续算法、评价或日志步骤使用。
cfg=merge_structs(default_config(),userCfg);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isa(cecFunctionHandle,'function_handle')
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('run_cec_adapter:Handle','cecFunctionHandle must be a function handle.');
end
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if numel(bounds)~=2||bounds(1)>=bounds(2)
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('run_cec_adapter:Bounds','bounds must be [lower,upper].');
end

% [逐行说明] 计算或更新 `rows`，供后续算法、评价或日志步骤使用。
rows={};
% [逐行说明] 开始按给定索引范围逐项执行循环。
for d=dimensions(:)'
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for fid=functionIds(:)'
        % [逐行说明] 计算或更新 `f`，供后续算法、评价或日志步骤使用。
        f=@(x) cecFunctionHandle(x,fid);
        % [逐行说明] 计算或更新 `problem`，供后续算法、评价或日志步骤使用。
        problem=make_scalar_problem(f,bounds(1),bounds(2),d,cfg, ...
            sprintf('CEC_F%d_D%d',fid,d));
        % [逐行说明] 开始按给定索引范围逐项执行循环。
        for runID=1:cfg.experiment.numRuns
            % [逐行说明] 计算或更新 `local`，供后续算法、评价或日志步骤使用。
            local=cfg;
            % 函数、维度和运行编号共同决定算法种子，便于跨算法复用同一列表。
            local.algorithm.seed=300000+10000*d+100*fid+runID;
            % [逐行说明] 开始受保护执行区，用于捕获运行异常。
            try
                % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
                [best,~,curve,out]=ASA_FPO(problem,local); %#ok<ASGLU>
                % [逐行说明] 计算或更新 `status`，供后续算法、评价或日志步骤使用。
                status="ok";message="";
            % [逐行说明] 捕获前述受保护执行区产生的异常。
            catch ME
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if cfg.experiment.failFast,rethrow(ME);end
                % [逐行说明] 计算或更新 `best`，供后续算法、评价或日志步骤使用。
                best=NaN;out=struct();status="error";
                % [逐行说明] 计算或更新 `message`，供后续算法、评价或日志步骤使用。
                message=string(ME.identifier)+": "+string(ME.message);
            end
            % [逐行说明] 计算或更新 `rows(end+1,:)`，供后续算法、评价或日志步骤使用。
            rows(end+1,:)={fid,d,runID,local.algorithm.seed,best, ...
                getfield_default(out,'actualFEs',NaN), ...
                getfield_default(out,'runtime',NaN),status,message}; %#ok<AGROW>
        end
    end
end
% [逐行说明] 计算或更新 `results`，供后续算法、评价或日志步骤使用。
results=cell2table(rows,'VariableNames', ...
    {'FunctionID','Dimension','RunID','Seed','Best','FEs','Runtime','Status','Message'});

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if cfg.experiment.saveCsvSummary
    % [逐行说明] 计算或更新 `outDir`，供后续算法、评价或日志步骤使用。
    outDir=fullfile(cfg.experiment.outputDir,'cec_adapter');
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    if~isfolder(outDir),mkdir(outDir);end
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    writetable(results,fullfile(outDir,'cec_asa_fpo_runs.csv'));
end
end

function value=getfield_default(s,name,defaultValue)
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isstruct(s)&&isfield(s,name),value=s.(name);else,value=defaultValue;end
end
