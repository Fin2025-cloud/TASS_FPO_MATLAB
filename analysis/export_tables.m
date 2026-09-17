function files = export_tables(resultRoot,outputDir)
%EXPORT_TABLES 从已保存 CSV 生成汇总表，不重新运行算法。
if nargin<2||isempty(outputDir),outputDir=fullfile(resultRoot,'tables');end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
if~isfolder(outputDir),mkdir(outputDir);end
% [逐行说明] 计算或更新 `summary`，供后续算法、评价或日志步骤使用。
summary=summarize_results(resultRoot);
% [逐行说明] 计算或更新 `summaryFile`，供后续算法、评价或日志步骤使用。
summaryFile=fullfile(outputDir,'summary.csv');writetable(summary,summaryFile);
% [逐行说明] 计算或更新 `files`，供后续算法、评价或日志步骤使用。
files=struct('summary',summaryFile);
end
