function report = statistical_tests(data,referenceAlgorithm)
%STATISTICAL_TESTS 多算法多任务的非参数统计、Holm 校正和效应量。
%
% 输入 data 是长表，必须含：Algorithm、Task、Value。每个 Algorithm-Task
% 组合可有多次运行；函数先取中位数形成“算法×任务”矩阵，再进行 Friedman
% 检验。成对比较使用任务级中位数的 Wilcoxon 符号秩正态近似，并做 Holm
% 校正，同时给出 Vargha-Delaney A12 和 Cliff's delta。
%
% 说明：任务数很少或大量差值为 0 时，近似 p 值可能较粗。若 Statistics
% Toolbox 可用，可将结果与 friedman/signrank 复核，但不得选择性报告更有利
% 的版本。

% [逐行说明] 计算或更新 `required`，供后续算法、评价或日志步骤使用。
required={'Algorithm','Task','Value'};
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:numel(required)
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if ~ismember(required{i},data.Properties.VariableNames)
        % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
        error('statistical_tests:Columns','Missing column %s.',required{i});
    end
end
% [逐行说明] 计算或更新 `algorithms`，供后续算法、评价或日志步骤使用。
algorithms=unique(string(data.Algorithm),'stable');
% [逐行说明] 计算或更新 `tasks`，供后续算法、评价或日志步骤使用。
tasks=unique(string(data.Task),'stable');
% [逐行说明] 计算或更新 `A`，供后续算法、评价或日志步骤使用。
A=numel(algorithms);T=numel(tasks);
% [逐行说明] 计算或更新 `M`，供后续算法、评价或日志步骤使用。
M=nan(T,A);
% [逐行说明] 开始按给定索引范围逐项执行循环。
for t=1:T
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for a=1:A
        % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
        mask=string(data.Task)==tasks(t)&string(data.Algorithm)==algorithms(a);
        % [逐行说明] 计算或更新 `M(t,a)`，供后续算法、评价或日志步骤使用。
        M(t,a)=median(data.Value(mask),'omitnan');
    end
end
% [逐行说明] 计算或更新 `validRows`，供后续算法、评价或日志步骤使用。
validRows=all(isfinite(M),2);M=M(validRows,:);tasksUsed=tasks(validRows);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if size(M,1)<2,error('statistical_tests:Tasks','At least two complete tasks are required.');end

% Friedman：每个任务内越小排名越好。
ranks=zeros(size(M));
% [逐行说明] 开始按给定索引范围逐项执行循环。
for t=1:size(M,1),ranks(t,:)=tied_rank(M(t,:));end
% [逐行说明] 计算或更新 `meanRanks`，供后续算法、评价或日志步骤使用。
meanRanks=mean(ranks,1);
% [逐行说明] 计算或更新 `n`，供后续算法、评价或日志步骤使用。
n=size(M,1);k=size(M,2);
% [逐行说明] 计算或更新 `Q`，供后续算法、评价或日志步骤使用。
Q=12*n/(k*(k+1))*sum((meanRanks-(k+1)/2).^2);
% [逐行说明] 计算或更新 `pF`，供后续算法、评价或日志步骤使用。
pF=1-gammainc(Q/2,(k-1)/2,'lower');

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<2||isempty(referenceAlgorithm),referenceAlgorithm=algorithms(1);end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
ref=find(algorithms==string(referenceAlgorithm),1);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(ref),error('statistical_tests:Reference','Reference algorithm not found.');end
% [逐行说明] 计算或更新 `pairs`，供后续算法、评价或日志步骤使用。
pairs=cell(0,7);
% [逐行说明] 开始按给定索引范围逐项执行循环。
for a=1:A
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if a==ref,continue;end
    % [逐行说明] 计算或更新 `d`，供后续算法、评价或日志步骤使用。
    d=M(:,ref)-M(:,a); % 负值表示 reference 更小、更好
    % [逐行说明] 计算或更新 `[pW,zW,nEff]`，供后续算法、评价或日志步骤使用。
    [pW,zW,nEff]=wilcoxon_signed_rank(d);
    % [逐行说明] 计算或更新 `a12`，供后续算法、评价或日志步骤使用。
    a12=vargha_delaney_A12(M(:,ref),M(:,a));
    % [逐行说明] 计算或更新 `cliff`，供后续算法、评价或日志步骤使用。
    cliff=2*a12-1;
    % [逐行说明] 计算或更新 `pairs`，供后续算法、评价或日志步骤使用。
    pairs=[pairs;{algorithms(ref),algorithms(a),pW,zW,nEff,a12,cliff}]; %#ok<AGROW>
end
% [逐行说明] 计算或更新 `pairTable`，供后续算法、评价或日志步骤使用。
pairTable=cell2table(pairs,'VariableNames',{'Reference','Opponent','PValue','Z','N','A12','CliffsDelta'});
% [逐行说明] 计算或更新 `[pAdj,reject]`，供后续算法、评价或日志步骤使用。
[pAdj,reject]=holm_adjust(pairTable.PValue,0.05);
% [逐行说明] 计算或更新 `pairTable.HolmAdjustedP`，供后续算法、评价或日志步骤使用。
pairTable.HolmAdjustedP=pAdj;pairTable.Reject05=reject;

% [逐行说明] 计算或更新 `rankTable`，供后续算法、评价或日志步骤使用。
rankTable=table(algorithms(:),meanRanks(:),'VariableNames',{'Algorithm','MeanRank'});
% [逐行说明] 计算或更新 `rankTable`，供后续算法、评价或日志步骤使用。
rankTable=sortrows(rankTable,'MeanRank','ascend');
% [逐行说明] 计算或更新 `report`，供后续算法、评价或日志步骤使用。
report=struct();
% [逐行说明] 计算或更新 `report.friedman`，供后续算法、评价或日志步骤使用。
report.friedman=struct('Q',Q,'df',k-1,'pValue',pF,'numTasks',n);
% [逐行说明] 计算或更新 `report.rankTable`，供后续算法、评价或日志步骤使用。
report.rankTable=rankTable;
% [逐行说明] 计算或更新 `report.pairwise`，供后续算法、评价或日志步骤使用。
report.pairwise=pairTable;
% [逐行说明] 计算或更新 `report.matrix`，供后续算法、评价或日志步骤使用。
report.matrix=M;
% [逐行说明] 计算或更新 `report.tasks`，供后续算法、评价或日志步骤使用。
report.tasks=tasksUsed;
end

function r=tied_rank(x)
% 与 tiedrank 等价的最小实现，升序且并列取平均名次。
[sorted,order]=sort(x);r=zeros(size(x));i=1;
% [逐行说明] 在循环条件保持成立期间重复执行后续语句。
while i<=numel(x)
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    j=i;while j<numel(x)&&sorted(j+1)==sorted(i),j=j+1;end
    % [逐行说明] 计算或更新 `rankValue`，供后续算法、评价或日志步骤使用。
    rankValue=(i+j)/2;r(order(i:j))=rankValue;i=j+1;
end
end

function [p,z,n]=wilcoxon_signed_rank(d)
% 双侧 Wilcoxon 符号秩正态近似，含零差剔除和基本连续性修正。
d=d(:);d=d(isfinite(d)&abs(d)>eps);n=numel(d);
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if n==0,p=1;z=0;return;end
% [逐行说明] 计算或更新 `r`，供后续算法、评价或日志步骤使用。
r=tied_rank(abs(d));
% [逐行说明] 计算或更新 `Wplus`，供后续算法、评价或日志步骤使用。
Wplus=sum(r(d>0));
% [逐行说明] 计算或更新 `mu`，供后续算法、评价或日志步骤使用。
mu=sum(r)/2;
% 在零假设下，每个非零差值的符号等概率为正/负。使用实际平均秩计算
% var(W+) 可自然包含并列修正，比直接套用无并列公式更稳妥。
varW=sum(r.^2)/4;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if varW<=eps,p=1;z=0;return;end
% 连续性修正保留方向：d=reference-opponent，因此 z<0 表示参考算法
% 倾向取得更小（更好）的任务级中位数，z>0 表示参考算法倾向更差。
if Wplus>mu
    % [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
    z=(Wplus-mu-0.5)/sqrt(varW);
% [逐行说明] 在前一条件不成立时继续判断当前条件。
elseif Wplus<mu
    % [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
    z=(Wplus-mu+0.5)/sqrt(varW);
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
    z=0;
end
% [逐行说明] 计算或更新 `p`，供后续算法、评价或日志步骤使用。
p=erfc(abs(z)/sqrt(2));
end

function a=vargha_delaney_A12(x,y)
% [逐行说明] 计算或更新 `x`，供后续算法、评价或日志步骤使用。
x=x(:);y=y(:);wins=0;ties=0;
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:numel(x)
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    wins=wins+sum(x(i)<y);ties=ties+sum(x(i)==y);
end
% [逐行说明] 计算或更新 `a`，供后续算法、评价或日志步骤使用。
a=(wins+0.5*ties)/(numel(x)*numel(y));
end

function [adj,reject]=holm_adjust(p,alpha)
% [逐行说明] 计算或更新 `[m,order]`，供后续算法、评价或日志步骤使用。
[m,order]=sort(p(:));n=numel(m);adjSorted=zeros(n,1);running=0;
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:n
    % [逐行说明] 计算或更新 `value`，供后续算法、评价或日志步骤使用。
    value=(n-i+1)*m(i);running=max(running,value);adjSorted(i)=min(1,running);
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
adj=zeros(n,1);adj(order)=adjSorted;reject=adj<=alpha;
end
