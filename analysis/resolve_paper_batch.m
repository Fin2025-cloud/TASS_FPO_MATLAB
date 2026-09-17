function batchFolder = resolve_paper_batch(batchFolder,profile)
%RESOLVE_PAPER_BATCH Validate a batch folder or select the newest valid one.
if nargin<2 || isempty(profile), profile='formal'; end
if nargin>=1 && ~isempty(batchFolder)
    batchFolder=char(batchFolder);
    validate_batch(batchFolder);
    return;
end

paperDir=fullfile(project_root(),'results','paper');
items=dir(fullfile(paperDir,[char(profile) '_*']));
items=items([items.isdir]);
valid=false(size(items));
for k=1:numel(items)
    valid(k)=isfile(fullfile(items(k).folder,items(k).name,'run_summary.json'));
end
items=items(valid);
if isempty(items)
    error('paper:NoResultBatch', ...
        '没有在 %s 中找到包含 run_summary.json 的 %s 批次。',paperDir,profile);
end
[~,idx]=max([items.datenum]);
batchFolder=fullfile(items(idx).folder,items(idx).name);
validate_batch(batchFolder);
end

function validate_batch(batchFolder)
if ~isfolder(batchFolder)
    error('paper:ResultDirNotFound','结果目录不存在：%s',batchFolder);
end
summaryFile=fullfile(batchFolder,'run_summary.json');
if ~isfile(summaryFile)
    error('paper:SummaryNotFound','结果目录缺少 run_summary.json：%s',batchFolder);
end
end
