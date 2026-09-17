function check=paper_validate_solution(z,problem)
% Independent re-evaluation on two denser samplings; no feedback to optimizer.
% Numerical verification only, NOT a proof of continuous-time collision freedom.
cfg=problem.cfg;t=tic;
levels=zeros(1,2);results=cell(1,2);
for k=1:2
 c=cfg;
 c.path.M=min(cfg.paper.maxValidationPoints,max(cfg.path.M+1, ...
 ceil(cfg.path.M*cfg.paper.validationFactor*2^(k-1))));
 c.path.maxAdaptivePoints=max(c.path.M,min(cfg.paper.maxValidationPoints, ...
 cfg.path.maxAdaptivePoints*cfg.paper.validationFactor*2^(k-1)));
 c.path.maxSegmentLength=cfg.path.maxSegmentLength/(cfg.paper.validationFactor*2^(k-1));
 c.path.maxRefineRounds=max(cfg.path.maxRefineRounds,6);
 env=problem.env;
 if isfield(env,'cache'),env=rmfield(env,'cache');end
 p=make_problem(env,c);results{k}=p.evaluate(z);levels(k)=c.path.M;
end
r=results{2};
check=struct('passed',all(cellfun(@(x)x.isFeasible,results)), ...
 'levels',levels,'firstCV',results{1}.CV,'CV',r.CV,'F',r.F, ...
 'energy',r.cost.energy,'length',r.cost.length,'time',r.cost.time, ...
 'energyRelativeDifference',abs(r.cost.energy-results{1}.cost.energy)/max(abs(r.cost.energy),eps), ...
 'seconds',toc(t),'result',r,'evaluationCalls',2, ...
 'status','numerical_dense_check_not_continuous_certificate');
end

