function report=test_paper_extended()
% Additional numeric, real-terrain and mechanism block checks; no formal data.
c=paper_config('smoke');names={};
% Known analytic hover result in the implemented model.
m=struct('horizontalAirSpeed',[0;0],'verticalAirSpeed',[0;0],'deltaT',[2;3]);
[E,p]=energy_model_B(m,c);expected=5*(c.energy.B.P0+c.energy.B.Pi);
assert(abs(E-expected)<1e-9&&all(p>0));names{end+1}='Analytic hover power';
% Independently denser evaluation on the same curved control polygon.
env=build_synthetic_environment(c,1,123);pr=make_problem(env,c);
bad=pr.evaluate(.5*ones(1,pr.dim));
assert(~bad.isFeasible&&strcmp(bad.status,'unresolved_stationary_segment'));
t=linspace(0,1,c.path.K+2)';
control=bsxfun(@plus,env.start,bsxfun(@times,t,env.goal-env.start));
control(:,2)=control(:,2)+70*sin(pi*t);
control(:,3)=control(:,3)+40*sin(pi*t);
z=encode_control_points(control,c,pr.physicalLB,pr.physicalUB);
r=pr.evaluate(z);c2=c;c2.path.M=600;c2.path.maxAdaptivePoints=600;
r2=make_problem(env,c2);r2=r2.evaluate(z);
assert(isfinite(r.cost.smoothness)&&isfinite(r2.cost.smoothness));
assert(abs(r.cost.smoothness-r2.cost.smoothness)/max(r2.cost.smoothness,eps)<.12);
names{end+1}='Curvature integral resolution check';
% Verify exact packaged data bytes before loading only reviewed numeric x/y/Z.
cat=real_dem_catalog();
for k=1:numel(cat)
 a=fullfile(paper_root(),'data','dem','cache',cat(k).cacheFile);
 b=fullfile(paper_root(),'data','dem','geotiff',cat(k).geoTIFFFile);
 assert(strcmp(paper_hash(a,'file'),cat(k).cacheSHA256));
 assert(strcmp(paper_hash(b,'file'),cat(k).geoTIFFSHA256));
end
env=build_environment_candidate('S6-E',c);assert(env.meta.checksumVerified);
pr=make_problem(env,c);
control=bsxfun(@plus,env.start,bsxfun(@times,t,env.goal-env.start));
control(:,3)=control(:,3)+40*sin(pi*t);
zr=encode_control_points(control,c,pr.physicalLB,pr.physicalUB);
r=pr.evaluate(zr);
assert(isfinite(r.F)&&isfinite(r.CV)&&isfinite(r.cost.energy));
names{end+1}='Five DEM/cache checksums and real-terrain evaluation';
% Exercise all credit branches and factorial combinations with tiny budgets.
c.algorithm.MaxFEs=24;env=build_synthetic_environment(c,1,123);
for block={'factorial','credit','restart'}
 V=paper_variants(block{1});
 for k=1:numel(V)
  ck=paper_apply_variant(c,V(k));pr=make_problem(env,ck);rng(42);
  [~,~,~,o,a]=paper_audited_solver(pr,V(k));
  assert(o.actualFEs==24&&a.actualCalls==24);
 end
end
names{end+1}='Eight factorial, seven credit and two restart configurations';
report=struct('runtime',version,'passed',numel(names),'names',{names}, ...
 'timestamp',datestr(now,30),'isMATLAB',~logical(exist('OCTAVE_VERSION','builtin')), ...
 'purpose','Implementation verification; not paper experiment data');
paper_write_json(fullfile(paper_root(),'results','verification', ...
 ['extended_',datestr(now,30),'.json']),report);
disp(report);
end
