function [f,z,curve,out]=paper_reference_solver(p)
%PAPER_REFERENCE_SOLVER Transparent formula-level constrained reference adapter.
% NOT official author code. Delta: FE progress, immediate Deb greedy acceptance,
% clipping bounds and accounting for all candidate evaluations. No TAI/CDR/ASA.
cfg=p.cfg;N=cfg.algorithm.N;D=p.dim;B=cfg.algorithm.MaxFEs;
rng(cfg.algorithm.seed,'twister');t=tic;
X=reshape(tent_sequence(N*D,rand),N,D);R=cell(N,1);Hbest=X;HR=R;
G=[];GR=[];n=0;first=NaN;FE=[];BF=[];BC=[];
for i=1:N
 R{i}=ev(X(i,:));HR{i}=R{i};
end
while n<B
 progress=n/B;EA=2*(1-progress^2);h=.9-.8*progress;mu=mean(X,1);
 keys=cellfun(@(r)r.CV,HR);feas=cellfun(@(r)r.isFeasible,HR);
 ff=cellfun(@(r)r.F,HR);keys(feas)=ff(feas);
 [~,order]=sortrows([~feas,keys],[1 2]);elite=mean(Hbest(order(1:max(1,ceil(.1*N))),:),1);
 for i=1:N
  if n>=B,break;end
  E=EA*(2*rand-1);r=rand;second=[];
  if abs(E)>=1
   q=rand;
   if q<.33,xr=X(randi(N),:);a=rand;b=rand;y=xr-a*abs(xr-2*b*X(i,:));
   elseif q<.66,a=rand;y=(G-mu)-a*((p.ub-p.lb)*a+p.lb);
   else,a=rand;c=4*a*(1-a);y=X(i,:)+c*(Hbest(randi(N),:)-X(i,:))+a*(2*a-1)*(p.ub-p.lb)*.1;
   end
  else
   J=2*(1-max(rand,eps)^(1-progress));
   if r>=.5&&abs(E)<.5
    y=G-E*abs(G-X(i,:))+.3*rand*(Hbest(i,:)-X(i,:));
   elseif r>=.5
    y=(G-X(i,:))-E*abs(J*G-X(i,:));
   elseif abs(E)>=.5
    y=(1-.2)*(G-E*abs(J*G-X(i,:)))+.2*Hbest(i,:);
    second=G-E*abs(J*G-X(i,:))+.01*rand(1,D).*levy_flight(1,D,1.3+.3*rand);
   else
    if rand<.5,center=h*mu+(1-h)*elite;else,center=h*mu+(1-h)*G;end
    y=G-E*abs(J*G-center);
    second=G-E*abs(J*G-mu)+.01*rand(1,D).*levy_flight(1,D,1.3+.3*rand);
   end
  end
  y=min(max(y,p.lb),p.ub);rr=ev(y);
  if deb_better(rr,R{i},cfg.constraint.feasibilityTolerance)
   X(i,:)=y;R{i}=rr;
  elseif ~isempty(second)&&n<B
   second=min(max(second,p.lb),p.ub);rr=ev(second);
   if deb_better(rr,R{i},cfg.constraint.feasibilityTolerance),X(i,:)=second;R{i}=rr;end
  end
  if deb_better(R{i},HR{i},cfg.constraint.feasibilityTolerance),Hbest(i,:)=X(i,:);HR{i}=R{i};end
 end
end
f=GR.F;z=G;curve=struct('FE',FE,'bestF',BF,'bestCV',BC);
out=struct('bestResult',GR,'actualFEs',n,'firstFeasibleFE',first,'runtime',toc(t), ...
 'options',cfg,'referenceStatus','formula_reconstruction_constrained_adapter_not_official');
 function rr=ev(x)
  rr=p.evaluate(x);n=n+1;
  if isempty(GR)||deb_better(rr,GR,cfg.constraint.feasibilityTolerance),GR=rr;G=x;end
  if isnan(first)&&rr.isFeasible,first=n;end
  FE(end+1,1)=n;BF(end+1,1)=GR.F;BC(end+1,1)=GR.CV;
 end
end

