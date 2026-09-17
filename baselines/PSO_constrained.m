function [bestCost,bestZ,convergence,output]=PSO_constrained(problem,userOpts)
%PSO_CONSTRAINED 使用 Deb 规则和 MaxFEs 的约束粒子群基线。
%
% 默认不使用 TAI/CDR。设置 opts.baseline.useTAI=true 可用于“完整系统共享
% 初始化”实验；设置 useRepair=true 时必须在论文中明确所有算法共享修复。
opts=baseline_defaults(problem,userOpts);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
rng(opts.algorithm.seed,'twister');
% [逐行说明] 计算或更新 `startClock`，供后续算法、评价或日志步骤使用。
startClock=tic;
% [逐行说明] 计算或更新 `N`，供后续算法、评价或日志步骤使用。
N=opts.algorithm.N; D=problem.dim; MaxFEs=opts.algorithm.MaxFEs;
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=baseline_initial_population(problem,N,opts);
% [逐行说明] 计算或更新 `V`，供后续算法、评价或日志步骤使用。
V=zeros(N,D);
% [逐行说明] 计算或更新 `R`，供后续算法、评价或日志步骤使用。
R=cell(N,1); Pbest=X; PR=cell(N,1); G=[]; GR=[]; FEs=0; firstFeasibleFE=NaN;
% [逐行说明] 计算或更新 `logFE`，供后续算法、评价或日志步骤使用。
logFE=[]; logF=[]; logCV=[];
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:N
    % [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
    b=evaluate_baseline(X(i,:),[],problem,opts,MaxFEs-FEs);
    % [逐行说明] 计算或更新 `[FEs,firstFeasibleFE]`，供后续算法、评价或日志步骤使用。
    [FEs,firstFeasibleFE]=register_baseline_bundle(b,FEs,firstFeasibleFE); X(i,:)=b.bestZ; R{i}=b.bestResult; Pbest(i,:)=X(i,:); PR{i}=R{i};
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if isempty(GR)||deb_better(R{i},GR,opts.constraint.feasibilityTolerance), G=X(i,:); GR=R{i}; end
end
% [逐行说明] 在循环条件保持成立期间重复执行后续语句。
while FEs<MaxFEs
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:N
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if FEs>=MaxFEs, break; end
        % [逐行说明] 计算或更新 `V(i,:)`，供后续算法、评价或日志步骤使用。
        V(i,:)=opts.baseline.inertia*V(i,:)+opts.baseline.c1*rand(1,D).*(Pbest(i,:)-X(i,:))+ ...
            opts.baseline.c2*rand(1,D).*(G-X(i,:));
        % [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
        z=reflect_bounds(X(i,:)+V(i,:),problem.lb,problem.ub);
        % [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
        b=evaluate_baseline(z,R{i},problem,opts,MaxFEs-FEs);
        % [逐行说明] 计算或更新 `[FEs,firstFeasibleFE]`，供后续算法、评价或日志步骤使用。
        [FEs,firstFeasibleFE]=register_baseline_bundle(b,FEs,firstFeasibleFE);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deb_better(b.bestResult,R{i},opts.constraint.feasibilityTolerance), X(i,:)=b.bestZ; R{i}=b.bestResult; end
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deb_better(R{i},PR{i},opts.constraint.feasibilityTolerance), Pbest(i,:)=X(i,:); PR{i}=R{i}; end
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deb_better(R{i},GR,opts.constraint.feasibilityTolerance), G=X(i,:); GR=R{i}; end
    end
    % [逐行说明] 计算或更新 `logFE(end+1,1)`，供后续算法、评价或日志步骤使用。
    logFE(end+1,1)=FEs; logF(end+1,1)=GR.F; logCV(end+1,1)=GR.CV; %#ok<AGROW>
end
% [逐行说明] 计算或更新 `bestCost`，供后续算法、评价或日志步骤使用。
bestCost=GR.F; bestZ=G; convergence=struct('FE',logFE,'bestF',logF,'bestCV',logCV);
% [逐行说明] 计算或更新 `output`，供后续算法、评价或日志步骤使用。
output=struct('bestResult',GR,'actualFEs',FEs,'finalPopulation',X,'finalResults',{R},'options',opts,'firstFeasibleFE',firstFeasibleFE,'runtime',toc(startClock));
end
