function summary = summarize_results(resultRoot)
%SUMMARIZE_RESULTS 汇总正式实验结果，同时显式保留失败运行数量。
%
% 真实性设计
% -------------------------------------------------------------------------
% 1. 若根目录存在 master_results.csv，则只读取该主表，避免再次递归读取每个
%    单次 CSV 而把同一运行重复统计两遍；
% 2. 若主表不存在，才递归拼接单次 CSV，并排除 summary/master 等汇总文件；
% 3. 目标值统计对 NaN 使用 omitnan，但同时输出 TotalRuns 和 ErrorRuns，绝不
%    通过忽略 NaN 来隐藏算法失败；
% 4. FeasibleRate 的分母包含全部运行，失败运行在主表中被记为不可行。

% [逐行说明] 计算或更新 `masterFile`，供后续算法、评价或日志步骤使用。
masterFile=fullfile(resultRoot,'master_results.csv');
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isfile(masterFile)
    % [逐行说明] 计算或更新 `data`，供后续算法、评价或日志步骤使用。
    data=readtable(masterFile);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `files`，供后续算法、评价或日志步骤使用。
    files=dir(fullfile(resultRoot,'**','*.csv'));
    % [逐行说明] 计算或更新 `keep`，供后续算法、评价或日志步骤使用。
    keep=true(numel(files),1);
    % [逐行说明] 计算或更新 `excluded`，供后续算法、评价或日志步骤使用。
    excluded={'master_results.csv','summary.csv','statistical_report.csv'};
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:numel(files)
        % [逐行说明] 计算或更新 `keep(i)`，供后续算法、评价或日志步骤使用。
        keep(i)=~ismember(lower(files(i).name),excluded);
    end
    % [逐行说明] 计算或更新 `files`，供后续算法、评价或日志步骤使用。
    files=files(keep);
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if isempty(files)
        % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
        warning('summarize_results:Empty','No result CSV files found under %s.',resultRoot);
        % [逐行说明] 计算或更新 `summary`，供后续算法、评价或日志步骤使用。
        summary=table();
        % [逐行说明] 结束当前函数并把已计算结果返回调用方。
        return;
    end
    % [逐行说明] 计算或更新 `data`，供后续算法、评价或日志步骤使用。
    data=table();
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:numel(files)
        % [逐行说明] 计算或更新 `T`，供后续算法、评价或日志步骤使用。
        T=readtable(fullfile(files(i).folder,files(i).name));
        % 只拼接具有正式单次记录字段的表，避免误把消融/敏感性表混入。
        required={'algorithm','scenario','bestCost','isFeasible','runtime'};
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if all(ismember(required,T.Properties.VariableNames))
            % [逐行说明] 计算或更新 `data`，供后续算法、评价或日志步骤使用。
            data=[data;T]; %#ok<AGROW>
        end
    end
end

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(data)
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    warning('summarize_results:NoCompatibleRecords','No compatible run records found.');
    % [逐行说明] 计算或更新 `summary`，供后续算法、评价或日志步骤使用。
    summary=table();
    % [逐行说明] 结束当前函数并把已计算结果返回调用方。
    return;
end

% [逐行说明] 计算或更新 `[G,alg,scn]`，供后续算法、评价或日志步骤使用。
[G,alg,scn]=findgroups(string(data.algorithm),string(data.scenario));
% [逐行说明] 计算或更新 `medianF`，供后续算法、评价或日志步骤使用。
medianF=splitapply(@(x) median(x,'omitnan'),data.bestCost,G);
% [逐行说明] 计算或更新 `meanF`，供后续算法、评价或日志步骤使用。
meanF=splitapply(@(x) mean(x,'omitnan'),data.bestCost,G);
% [逐行说明] 计算或更新 `stdF`，供后续算法、评价或日志步骤使用。
stdF=splitapply(@(x) std(x,'omitnan'),data.bestCost,G);
% [逐行说明] 计算或更新 `feasibleRate`，供后续算法、评价或日志步骤使用。
feasibleRate=splitapply(@mean,double(data.isFeasible),G);
% [逐行说明] 计算或更新 `medianFirst`，供后续算法、评价或日志步骤使用。
medianFirst=splitapply(@(x) median(x,'omitnan'),data.firstFeasibleFE,G);
% [逐行说明] 计算或更新 `medianRuntime`，供后续算法、评价或日志步骤使用。
medianRuntime=splitapply(@(x) median(x,'omitnan'),data.runtime,G);
% [逐行说明] 计算或更新 `totalRuns`，供后续算法、评价或日志步骤使用。
totalRuns=splitapply(@numel,data.bestCost,G);

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ismember('status',data.Properties.VariableNames)
    % [逐行说明] 计算或更新 `isError`，供后续算法、评价或日志步骤使用。
    isError=~strcmpi(string(data.status),'ok');
    % [逐行说明] 计算或更新 `errorRuns`，供后续算法、评价或日志步骤使用。
    errorRuns=splitapply(@sum,double(isError),G);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `errorRuns`，供后续算法、评价或日志步骤使用。
    errorRuns=splitapply(@(x) sum(~isfinite(x)),data.bestCost,G);
end

% [逐行说明] 计算或更新 `summary`，供后续算法、评价或日志步骤使用。
summary=table(alg,scn,totalRuns,errorRuns,medianF,meanF,stdF,feasibleRate, ...
    medianFirst,medianRuntime,'VariableNames', ...
    {'Algorithm','Scenario','TotalRuns','ErrorRuns','MedianF','MeanF','StdF', ...
     'FeasibleRate','MedianFirstFeasibleFE','MedianRuntime'});
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
writetable(summary,fullfile(resultRoot,'summary.csv'));
end
