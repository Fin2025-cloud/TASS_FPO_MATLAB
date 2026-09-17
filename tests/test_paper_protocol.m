function report=test_paper_protocol()
%TEST_PAPER_PROTOCOL Small deterministic implementation tests, never paper data.
started=datestr(now,30);
names={};seconds=[];
run_case('SHA256 known vector',@hash_case);
run_case('Deb ordering',@test_deb_rule);
run_case('B-spline endpoints',@test_bspline);
run_case('Static segment collision',@test_static_collision);
run_case('Dynamic crossing collision',@test_dynamic_collision);
run_case('Credit accounting and selectors',@credit_case);
run_case('Variant coverage',@variant_case);
run_case('Formal evidence gate',@gate_case);
run_case('All core solvers exact FE and reproducibility',@solver_case);
run_case('Immutable record and resume',@record_case);
report=struct('started',started,'finished',datestr(now,30),'runtime',version, ...
 'isMATLAB',~logical(exist('OCTAVE_VERSION','builtin')), ...
 'passed',numel(names),'names',{names},'seconds',seconds, ...
 'purpose','Implementation tests only; not scientific experiment results');
folder=fullfile(paper_root(),'results','verification');
if ~isfolder(folder),mkdir(folder);end
paper_write_json(fullfile(folder,['tests_',started,'.json']),report);
disp(report);
 function run_case(name,fun)
  t=tic;fun();names{end+1}=name;seconds(end+1)=toc(t);
  fprintf('PASS %s (%.3fs)\n',name,seconds(end));
 end
end
function hash_case()
assert(strcmp(paper_hash('abc'),'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'));
end
function credit_case()
c=paper_config('smoke');a=result_stub(10,0);a.isFeasible=true;
b=result_stub(8,0);b.isFeasible=true;f=result_stub(7,0);f.isFeasible=true;
[r,d]=strategy_reward(a,b,f,3,1,c);
assert(abs(r-(d.raw+c.strategy.lambdaRepair*d.repair)/3)<1e-12);
c.strategy.costMode='fixed';c.strategy.fixedCost=1;
[r2,d2]=strategy_reward(a,b,f,3,1,c);assert(abs(r2-r*3)<1e-12&&d2.denominator==1);
c.strategy.creditMode='accepted_net';f=a;
[r3,~]=strategy_reward(a,b,f,3,1,c);assert(r3==0);
s=init_strategy_stats(c);s.exp.Q=[-1,0,2];
for selector={'softmax','probability_matching'}
 c.strategy.selector=selector{1};p=strategy_probabilities(s.exp,c);
 assert(abs(sum(p)-1)<1e-12&&all(p>=s.exp.pMin-1e-12));
end
end
function variant_case()
v=paper_variants('factorial');assert(numel(v)==8);
assert(numel(unique({v.id}))==8);
assert(numel(paper_variants('credit'))==7);
end
function gate_case()
c=paper_config('formal');caught=false;
try,paper_preflight(c);catch ME,caught=strcmp(ME.identifier,'paper:FormalBlocked');end
assert(caught,'Formal execution must be blocked before human review.');
end
function solver_case()
c=paper_config('smoke');c.algorithm.MaxFEs=60;
env=build_synthetic_environment(c,1,123);
v=paper_variants('main');
for k=1:numel(v)
 ck=paper_apply_variant(c,v(k));p=make_problem(env,ck);rng(17,'twister');
 [f,z,~,o,a]=paper_audited_solver(p,v(k));
 assert(a.actualCalls==60&&o.actualFEs==60&&isfinite(f)&&all(isfinite(z)));
 if strcmp(v(k).id,'TAAS-FPO')
  assert(~isempty(o.strategyEvents));
  rng(17,'twister');[f2,z2,~,o2,a2]=paper_audited_solver(p,v(k));
  assert(isequal(z,z2)&&f==f2&&isequal(a.trace,a2.trace)&&o2.actualFEs==60);
  val=paper_validate_solution(z,p);assert(val.evaluationCalls==2);
 end
end
end
function record_case()
c=paper_config('smoke');c.algorithm.MaxFEs=30;
c.paper.candidateIds={'S1-B'};c.paper.seedIds=1;
c.paper.outputRoot=fullfile(paper_root(),'results','verification', ...
 ['record_test_',datestr(now,30),'_',num2str(randi(1e8))]);
r=paper_run(c,{'FPO-N'});assert(numel(r)==1&&strcmp(r.status,'complete'),r.errorMessage);
r2=paper_run(c,{'FPO-N'});assert(strcmp(r.recordSHA256,r2.recordSHA256));
m=paper_code_manifest();v=paper_variants('main');v=v(strcmp({v.id},'FPO-N'));
h=paper_protocol_signature(c,v,m);c.algorithm.MaxFEs=31;
assert(~strcmp(h,paper_protocol_signature(c,v,m)));
end
