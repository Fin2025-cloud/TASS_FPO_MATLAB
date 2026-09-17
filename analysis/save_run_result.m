function files = save_run_result(outputDir,record,fullData)
%SAVE_RUN_RESULT 原子式保存单次运行的 MAT 完整日志和 CSV 摘要。
%
% 先写入 .partial 临时文件，再使用 movefile 替换目标文件。这样断电或手动
% 中止时不会留下“文件名存在但内容不完整”的结果，恢复运行也不会误跳过。

if ~exist(outputDir,'dir'),mkdir(outputDir);end
required={'algorithm','scenario','runID','seed'};
for i=1:numel(required)
    if ~isfield(record,required{i}),error('save_run_result:Field','Missing %s.',required{i});end
end
base=sprintf('%s_%s_run%03d_seed%d',sanitize(record.algorithm),sanitize(record.scenario),record.runID,record.seed);
matFile=fullfile(outputDir,[base,'.mat']);
csvFile=fullfile(outputDir,[base,'.csv']);
tmpMat=fullfile(outputDir,[base,'.partial.mat']);
tmpCsv=fullfile(outputDir,[base,'.partial.csv']);

% 删除上次异常退出遗留的临时文件，不触碰正式结果。
if isfile(tmpMat),delete(tmpMat);end
if isfile(tmpCsv),delete(tmpCsv);end

save(tmpMat,'record','fullData','-v7.3');
writetable(struct2table(record),tmpCsv);
[ok,msg]=movefile(tmpMat,matFile,'f');
if ~ok,error('save_run_result:MoveMAT','Cannot finalize MAT file: %s',msg);end
[ok,msg]=movefile(tmpCsv,csvFile,'f');
if ~ok,error('save_run_result:MoveCSV','Cannot finalize CSV file: %s',msg);end
files=struct('mat',matFile,'csv',csvFile);
end
function s=sanitize(x)
s=regexprep(char(string(x)),'[^a-zA-Z0-9_-]','_');
end
