function V=paper_variants(block)
%PAPER_VARIANTS Factorial and credit controls; never silently substitute a solver.
if nargin<1,block='main';end
V=struct('id',{},'solver',{},'tai',{},'asa',{},'cdr',{},'restart',{}, ...
 'selector',{},'creditMode',{},'costMode',{},'lambda',{});
switch lower(block)
 case 'main'
  V(end+1)=v('FPO-reference','reference',0,0,0,0);
  V(end+1)=v('FPO-N','taas',0,0,0,0);
  V(end+1)=v('ASA-FPO','taas',0,1,0,0);
  V(end+1)=v('TAAS-FPO','taas',1,1,1,1);
  V(end+1)=v('DE','de',0,0,0,0);
  V(end+1)=v('PSO','pso',0,0,0,0);
  V(end+1)=v('GWO','gwo',0,0,0,0);
 case 'factorial'
  for k=0:7
   b=dec2bin(k,3)-'0';
   V(end+1)=v(sprintf('T%dA%dC%d',b), 'taas',b(1),b(2),b(3),0);
  end
 case 'credit'
  V(end+1)=v('credit-full','taas',1,1,1,0);
  V(end+1)=v('credit-uniform','taas',1,0,1,0);
  V(end+1)=v('credit-probmatch','taas',1,1,1,0); V(end).selector='probability_matching';
  V(end+1)=v('credit-fixedcost','taas',1,1,1,0); V(end).costMode='fixed';
  V(end+1)=v('credit-allrepair','taas',1,1,1,0); V(end).lambda=1;
  V(end+1)=v('credit-norepaircredit','taas',1,1,1,0); V(end).lambda=0;
  V(end+1)=v('credit-netaccepted','taas',1,1,1,0); V(end).creditMode='accepted_net';
 case 'restart'
  V(end+1)=v('TAAS-noRestart','taas',1,1,1,0);
  V(end+1)=v('TAAS-FPO','taas',1,1,1,1);
 otherwise
  error('paper:Block','Unknown block %s.',block);
end
end
function a=v(id,solver,tai,asa,cdr,restart)
a=struct('id',id,'solver',solver,'tai',logical(tai),'asa',logical(asa), ...
'cdr',logical(cdr),'restart',logical(restart),'selector','softmax', ...
'creditMode','split','costMode','actual','lambda',.30);
end
