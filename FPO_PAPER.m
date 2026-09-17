function varargout=FPO_PAPER(action,varargin)
%FPO_PAPER v2 evidence-bound experiments alongside the v1.3.1 environment studio.
% FPO_PAPER('smoke')                         tiny development check
% FPO_PAPER('pilot')                         3-seed development run
% cfg=FPO_PAPER('config','formal')            configure, does not execute
% FPO_PAPER('run',cfg,{'TAAS-FPO'})            explicit reviewed subset
% FPO_PAPER('preflight',cfg)                  no optimizer
% FPO_PAPER('variants','factorial')           inspect all eight combinations
% FPO_PAPER('tests')                         deterministic + smoke tests
% FPO_PAPER('report',batchFolder)             aggregate saved runs
startup();
if nargin<1,action='help';end
out=[];
switch lower(action)
 case 'help',help FPO_PAPER;
 case 'config',out=paper_config(varargin{:});
 case 'variants',out=paper_variants(varargin{:});
 case 'preflight'
  if isempty(varargin),cfg=paper_config('pilot');else,cfg=varargin{1};end
  out=paper_preflight(cfg);
 case {'smoke','pilot','formal'}
  cfg=paper_config(action);
  if ~isempty(varargin),cfg=merge_structs(cfg,varargin{1});end
  out=paper_run(cfg);
 case 'run',out=paper_run(varargin{:});
 case 'report',out=paper_report(varargin{:});
 case 'tests',out=test_paper_protocol();
 otherwise,error('paper:Action','Unknown action %s.',action);
end
if nargout>0,varargout{1}=out;end
end

