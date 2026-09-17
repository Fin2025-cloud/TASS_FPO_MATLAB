function h = plot_convergence_fe(curve)
%PLOT_CONVERGENCE_FE 以真实函数评价次数而非迭代代数绘制收敛过程。
%
% 综合目标 F 可能为负（例如某些通用基准函数），而约束违反度 CV 非负且
% 常跨越多个数量级。因此使用双纵轴：F 保持线性坐标，CV 使用对数坐标，
% 避免 semilogy 把负目标值隐藏或错误裁剪。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(curve.FE)
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    warning('plot_convergence_fe:Empty','No convergence data.');
    % [逐行说明] 计算或更新 `h`，供后续算法、评价或日志步骤使用。
    h=[];
    % [逐行说明] 结束当前函数并把已计算结果返回调用方。
    return;
end

% [逐行说明] 计算或更新 `ax`，供后续算法、评价或日志步骤使用。
ax=gca;
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
yyaxis(ax,'left');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
plot(curve.FE,curve.bestF,'LineWidth',1.6);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
ylabel('Best objective F');

% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
yyaxis(ax,'right');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
semilogy(curve.FE,max(curve.bestCV,eps),'--','LineWidth',1.4);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
ylabel('Best constraint violation CV');

% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
xlabel('Function evaluations (FEs)');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
grid on;
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
title('Convergence under equal FE budget');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
legend('Best F','Best CV','Location','best');
% [逐行说明] 计算或更新 `h`，供后续算法、评价或日志步骤使用。
h=ax;
end
