function [bestCost,bestZ,convergence,output]=GWO_constrained(problem,userOpts)
%GWO_CONSTRAINED 使用 Deb 排名和 MaxFEs 的灰狼优化基线。
opts=baseline_defaults(problem,userOpts);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
rng(opts.algorithm.seed,'twister');
% [逐行说明] 计算或更新 `startClock`，供后续算法、评价或日志步骤使用。
startClock=tic;
% [逐行说明] 计算或更新 `N`，供后续算法、评价或日志步骤使用。
N=opts.algorithm.N; D=problem.dim; MaxFEs=opts.algorithm.MaxFEs;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if N<3, error('GWO_constrained:Population','GWO requires N>=3.'); end
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=baseline_initial_population(problem,N,opts);R=cell(N,1);FEs=0;firstFeasibleFE=NaN;
% [逐行说明] 开始按给定索引范围逐项执行循环。
for i=1:N
    % [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
    b=evaluate_baseline(X(i,:),[],problem,opts,MaxFEs-FEs);[FEs,firstFeasibleFE]=register_baseline_bundle(b,FEs,firstFeasibleFE);X(i,:)=b.bestZ;R{i}=b.bestResult;
end
% [逐行说明] 计算或更新 `logFE`，供后续算法、评价或日志步骤使用。
logFE=[];logF=[];logCV=[];
% [逐行说明] 在循环条件保持成立期间重复执行后续语句。
while FEs<MaxFEs
    % [逐行说明] 计算或更新 `order`，供后续算法、评价或日志步骤使用。
    order=deb_rank(R); alpha=X(order(1),:); beta=X(order(2),:); delta=X(order(3),:);
    % [逐行说明] 计算或更新 `progress`，供后续算法、评价或日志步骤使用。
    progress=FEs/MaxFEs; a=2*(1-progress);
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:N
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if FEs>=MaxFEs,break;end
        % [逐行说明] 计算或更新 `A1`，供后续算法、评价或日志步骤使用。
        A1=2*a*rand(1,D)-a;C1=2*rand(1,D);X1=alpha-A1.*abs(C1.*alpha-X(i,:));
        % [逐行说明] 计算或更新 `A2`，供后续算法、评价或日志步骤使用。
        A2=2*a*rand(1,D)-a;C2=2*rand(1,D);X2=beta-A2.*abs(C2.*beta-X(i,:));
        % [逐行说明] 计算或更新 `A3`，供后续算法、评价或日志步骤使用。
        A3=2*a*rand(1,D)-a;C3=2*rand(1,D);X3=delta-A3.*abs(C3.*delta-X(i,:));
        % [逐行说明] 计算或更新 `z`，供后续算法、评价或日志步骤使用。
        z=reflect_bounds((X1+X2+X3)/3,problem.lb,problem.ub);
        % [逐行说明] 计算或更新 `b`，供后续算法、评价或日志步骤使用。
        b=evaluate_baseline(z,R{i},problem,opts,MaxFEs-FEs);[FEs,firstFeasibleFE]=register_baseline_bundle(b,FEs,firstFeasibleFE);
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if deb_better(b.bestResult,R{i},opts.constraint.feasibilityTolerance),X(i,:)=b.bestZ;R{i}=b.bestResult;end
    end
    % [逐行说明] 计算或更新 `order`，供后续算法、评价或日志步骤使用。
    order=deb_rank(R);GR=R{order(1)};
    % [逐行说明] 计算或更新 `logFE(end+1,1)`，供后续算法、评价或日志步骤使用。
    logFE(end+1,1)=FEs;logF(end+1,1)=GR.F;logCV(end+1,1)=GR.CV; %#ok<AGROW>
end
% [逐行说明] 计算或更新 `order`，供后续算法、评价或日志步骤使用。
order=deb_rank(R);bestZ=X(order(1),:);GR=R{order(1)};bestCost=GR.F;
% [逐行说明] 计算或更新 `convergence`，供后续算法、评价或日志步骤使用。
convergence=struct('FE',logFE,'bestF',logF,'bestCV',logCV);
% [逐行说明] 计算或更新 `output`，供后续算法、评价或日志步骤使用。
output=struct('bestResult',GR,'actualFEs',FEs,'finalPopulation',X,'finalResults',{R},'options',opts,'firstFeasibleFE',firstFeasibleFE,'runtime',toc(startClock));
end
