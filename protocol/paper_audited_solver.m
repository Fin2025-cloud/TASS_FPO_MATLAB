function [bestF,bestZ,convergence,out,audit]=paper_audited_solver(problem,variant)
%PAPER_AUDITED_SOLVER Independent actual evaluator-call count and raw FE trace.
% The wrapper never changes objective/constraints or repairs the returned path.
cfg=problem.cfg;budget=cfg.algorithm.MaxFEs;
n=0; evalSeconds=0;pointCount=0;
first=NaN; best=[]; original=problem.evaluate;
trace=nan(budget,5);
problem.evaluate=@counted;
switch variant.solver
 case 'taas',[bestF,bestZ,convergence,out]=TAAS_FPO(problem,struct());
 case 'reference',[bestF,bestZ,convergence,out]=paper_reference_solver(problem);
 case 'de',[bestF,bestZ,convergence,out]=DE_constrained(problem,struct());
 case 'pso',[bestF,bestZ,convergence,out]=PSO_constrained(problem,struct());
 case 'gwo',[bestF,bestZ,convergence,out]=GWO_constrained(problem,struct());
 otherwise,error('paper:UnverifiedSolver','No reviewed adapter for %s.',variant.solver);
end
if out.actualFEs~=n,error('paper:BudgetMismatch','Reported %d, observed %d.',out.actualFEs,n);end
if n>budget,error('paper:BudgetExceeded','Evaluator exceeded budget.');end
if cfg.experiment.requireExactFEs&&n~=budget
 error('paper:IncompleteBudget','Expected exactly %d evaluator calls, observed %d.',budget,n);
end
audit=struct('actualCalls',n,'budget',budget,'evaluationSeconds',evalSeconds, ...
 'samplePoints',pointCount,'firstSearchFeasibleFE',first, ...
 'traceColumns',{{'FE','rawF','rawCV','bestF','bestCV'}},'trace',trace(1:n,:));
 function r=counted(z)
  if n>=budget,error('paper:BudgetExceeded','Attempt to evaluate beyond MaxFEs.');end
  n=n+1;t=tic;r=original(z);evalSeconds=evalSeconds+toc(t);
  if isfield(r,'pathSamples'),pointCount=pointCount+size(r.pathSamples,1);end
  if isempty(best)||deb_better(r,best,cfg.constraint.feasibilityTolerance),best=r;end
  if isnan(first)&&r.isFeasible,first=n;end
  trace(n,:)=[n,r.F,r.CV,best.F,best.CV];
 end
end
