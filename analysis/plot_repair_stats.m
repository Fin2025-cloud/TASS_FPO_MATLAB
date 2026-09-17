function h = plot_repair_stats(repairStats)
%PLOT_REPAIR_STATS 绘制各违反类型修复动作次数。
if ~isfield(repairStats,'byType')||isempty(fieldnames(repairStats.byType))
    % [逐行说明] 计算或更新 `warning('plot_repair_stats:Empty','No repair actions were recorded.');h`，供后续算法、评价或日志步骤使用。
    warning('plot_repair_stats:Empty','No repair actions were recorded.');h=[];return;
end
% [逐行说明] 计算或更新 `names`，供后续算法、评价或日志步骤使用。
names=fieldnames(repairStats.byType);values=zeros(numel(names),1);
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:numel(names),values(i)=repairStats.byType.(names{i});end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
bar(values);set(gca,'XTick',1:numel(names),'XTickLabel',names,'XTickLabelRotation',30);
% [逐行说明] 计算或更新 `ylabel('Repair action count');title(sprintf('Repair calls`，供后续算法、评价或日志步骤使用。
ylabel('Repair action count');title(sprintf('Repair calls=%d, extra evaluations=%d',repairStats.calls,repairStats.evaluations));grid on;h=gca;
end
