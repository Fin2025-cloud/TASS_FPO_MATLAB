function h = plot_strategy_prob(log)
%PLOT_STRATEGY_PROB 绘制七策略概率随 FE 的变化。
if isempty(log.FE)||isempty(log.strategyProb)
    % [逐行说明] 计算或更新 `warning('plot_strategy_prob:Empty','No strategy probability log.'); h`，供后续算法、评价或日志步骤使用。
    warning('plot_strategy_prob:Empty','No strategy probability log.'); h=[]; return;
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
plot(log.FE,log.strategyProb,'LineWidth',1.25);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
xlabel('Function evaluations (FEs)');ylabel('Selection probability');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
legend({'Team','Tree','Multi','Siege','Dive','High-ground','Encircle'},'Location','eastoutside');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
ylim([0,1]);grid on;title('Stage-wise adaptive strategy probabilities');
% [逐行说明] 计算或更新 `h`，供后续算法、评价或日志步骤使用。
h=gca;
end
