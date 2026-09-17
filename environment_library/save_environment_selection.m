function selection = save_environment_selection(ids,cfg)
%SAVE_ENVIRONMENT_SELECTION 验证并保存一组六场景候选环境。
%
% 保存动作不会运行优化器。除候选编号外，同时保存目录条目、快速环境指标和
% 数据来源摘要，便于以后确认“当时选的是哪一组环境”。正式实验开始时还会
% 在结果目录中建立不可混写的冻结快照。

if nargin<2||isempty(cfg),cfg=environment_config();end
if numel(ids)~=6,error('Provide exactly one ID for each scenario.');end
ids=cellstr(string(ids(:)'));
catalogItems=repmat(get_environment_candidate(ids{1}),6,1);
metrics=cell(6,1);
for s=1:6
    item=get_environment_candidate(ids{s});
    if item.scenarioId~=s,error('ID %s is not an S%d candidate.',ids{s},s);end
    env=build_environment_candidate(ids{s},cfg);
    catalogItems(s)=item;
    metrics{s}=compute_environment_metrics(env,cfg);
end
selection=struct();
selection.version='1.3.0';
selection.created=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
selection.status='provisional_environment_selection';
selection.candidateIds=ids;
selection.catalogItems=catalogItems;
selection.metrics=metrics;

root=fileparts(fileparts(mfilename('fullpath')));
folder=fullfile(root,'data','selections');
if ~isfolder(folder),mkdir(folder);end
matFile=fullfile(folder,'selected_environments.mat');
jsonFile=fullfile(folder,'selected_environments.json');
save(matFile,'selection','-v7.3');
text=jsonencode(selection);
try,text=jsonencode(selection,'PrettyPrint',true);catch,end
fid=fopen(jsonFile,'w');
if fid<0,error('save_environment_selection:FileOpen','Cannot open %s.',jsonFile);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,text,'char');
fprintf('Saved six provisional environments:\n  %s\n',strjoin(ids,', '));
fprintf('No optimizer was run. File: %s\n',matFile);
end
