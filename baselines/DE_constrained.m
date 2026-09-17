function [bestCost,bestZ,convergence,output]=DE_constrained(problem,userOpts)
%DE_CONSTRAINED 使用 Deb 规则和 MaxFEs 的 DE/rand/1/bin 基线。
opts=baseline_defaults(problem,userOpts);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
rng(opts.algorithm.seed,'twister');
% [逐行说明] 计算或更新 `startClock`，供后续算法、评价或日志步骤使用。
startClock=tic;
% [逐行说明] 计算或更新 `N`，供后续算法、评价或日志步骤使用。
N=opts.algorithm.N; D=problem.dim; MaxFEs=opts.algorithm.MaxFEs;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if N<4, error('DE_constrained:Population','DE requires N>=4.'); end
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=baseline_initial_population(problem,N,opts); R=cell(N,1); FEs=0; firstFeasibleFE=NaN; G=[]; GR=[];
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:N
    % [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
    b=evaluate_baseline(X(i,:),[],problem,opts,MaxFEs-FEs); [FEs,firstFeasibleFE]=register_baseline_bundle(b,FEs,firstFeasibleFE);
    % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
    X(i,:)=b.bestZ; R{i}=b.bestResult;
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if isempty(GR)||deb_better(R{i},GR,opts.constraint.feasibilityTolerance), G=X(i,:); GR=R{i}; end
end
% [逐行说明] 计算或更新 `logFE`，供后续算法、评价或日志步骤使用。
logFE=[];logF=[];logCV=[];
% [逐行说明] 在循环条件保持成立期间重复执行后续语句。
while FEs<MaxFEs
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:N
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if FEs>=MaxFEs, break; end
        % [逐行说明] 计算或更新 `pool`，供后续算法、评价或日志步骤使用。
        pool=setdiff(1:N,i); p=pool(randperm(numel(pool),3));
        % [逐行说明] 计算或更新 `mutant`，供后续算法、评价或日志步骤使用。
        mutant=X(p(1),:)+opts.baseline.DE_F*(X(p(2),:)-X(p(3),:));
        % [逐行说明] 计算或更新 `mutant`，供后续算法、评价或日志步骤使用。
        mutant=reflect_bounds(mutant,problem.lb,problem.ub);
        % [逐行说明] 计算或更新 `mask`，供后续算法、评价或日志步骤使用。
        mask=rand(1,D)<opts.baseline.DE_CR; mask(randi(D))=true;
        % [逐行说明] 计算或更新 `trial`，供后续算法、评价或日志步骤使用。
        trial=X(i,:); trial(mask)=mutant(mask);
        % [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
        b=evaluate_baseline(trial,R{i},problem,opts,MaxFEs-FEs); [FEs,firstFeasibleFE]=register_baseline_bundle(b,FEs,firstFeasibleFE);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deb_better(b.bestResult,R{i},opts.constraint.feasibilityTolerance), X(i,:)=b.bestZ; R{i}=b.bestResult; end
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deb_better(R{i},GR,opts.constraint.feasibilityTolerance), G=X(i,:); GR=R{i}; end
    end
    % [逐行说明] 计算或更新 `logFE(end+1,1)`，供后续算法、评价或日志步骤使用。
    logFE(end+1,1)=FEs;logF(end+1,1)=GR.F;logCV(end+1,1)=GR.CV; %#ok<AGROW>
end
% [逐行说明] 计算或更新 `bestCost`，供后续算法、评价或日志步骤使用。
bestCost=GR.F;bestZ=G;convergence=struct('FE',logFE,'bestF',logF,'bestCV',logCV);
% [逐行说明] 计算或更新 `output`，供后续算法、评价或日志步骤使用。
output=struct('bestResult',GR,'actualFEs',FEs,'finalPopulation',X,'finalResults',{R},'options',opts,'firstFeasibleFE',firstFeasibleFE,'runtime',toc(startClock));
end
