function summaries=paper_run(cfg,variantIds)
%PAPER_RUN Sequential immutable per-run records. Failed runs remain visible.
if nargin<1,cfg=paper_config('smoke');end
V=paper_variants(cfg.paper.block);
if nargin>1&&~isempty(variantIds)
 take=ismember({V.id},variantIds);
 if sum(take)~=numel(variantIds),error('paper:Variant','Unknown/duplicate variant ID.');end
 V=V(take);
end
pre=paper_preflight(cfg,V);code=paper_code_manifest();
signature=pre.protocolSHA256;
batch=fullfile(cfg.paper.outputRoot,[cfg.paper.profile,'_',signature(1:16)]);
if ~isfolder(batch),mkdir(batch);end
manifestFile=fullfile(batch,'protocol.json');
manifest=struct('signature',signature,'config',cfg,'variants',V,'code',code, ...
 'created',datestr(now,30),'runtime',version,'computer',computer);
if isfile(manifestFile)
 previous=jsondecode(fileread(manifestFile));
 if ~strcmp(previous.signature,signature),error('paper:Signature','Protocol collision.');end
else,paper_write_json(manifestFile,manifest);end
summaryTemplate=empty_row('',signature,'','',NaN,cfg);
summaries=repmat(summaryTemplate,0,1);
for ci=1:numel(cfg.paper.candidateIds)
 candidate=cfg.paper.candidateIds{ci};
 for vi=1:numel(V)
  for si=1:numel(cfg.paper.seedIds)
   current=paper_code_manifest();
   if ~strcmp(current.sha256,code.sha256)
    error('paper:ChangedInputs','Code or input data changed during this batch.');
   end
   seedId=cfg.paper.seedIds(si);
   key=sprintf('%s_%s_seed%03d',candidate,V(vi).id,seedId);
   runDir=fullfile(batch,key);
   summaryFile=fullfile(runDir,'summary.json');
   if isfile(summaryFile)
    old=jsondecode(fileread(summaryFile));
    if cfg.paper.resume&&strcmp(old.signature,signature)
     if strcmp(old.status,'complete')
      recordFile=fullfile(runDir,'record.mat');
      if ~isfile(recordFile)||~strcmp(paper_hash(recordFile,'file'),old.recordSHA256)
       error('paper:RecordIntegrity','Record missing/changed for %s.',key);
      end
     end
     fprintf('RESUME %s [%s]\n',key,old.status);
     summaries(end+1)=normalize_summary(old,summaryTemplate);continue;
    end
    error('paper:Overwrite','Existing run is immutable: %s.',runDir);
   end
   if isfolder(runDir),error('paper:Incomplete','Incomplete run exists: inspect and archive explicitly: %s.',runDir);end
   mkdir(runDir);
   row=empty_row(key,signature,candidate,V(vi).id,seedId,cfg);
   try
    runCfg=paper_apply_variant(cfg,V(vi));
    runCfg.algorithm.seed=cfg.experiment.baseAlgorithmSeed+10000*ci+seedId;
    rng(runCfg.algorithm.seed,'twister');
    prep=tic;env=build_environment_candidate(candidate,runCfg);
    problem=make_problem(env,runCfg);
    row.preparationSeconds=toc(prep);
    row.environmentSHA256=paper_hash(jsonencode(env));
    search=tic;
    [f,z,conv,out,audit]=paper_audited_solver(problem,V(vi));
    row.searchSeconds=toc(search);
    check=paper_validate_solution(z,problem);
    row.validationSeconds=check.seconds;
    row.actualFEs=audit.actualCalls;
    row.searchFeasible=out.bestResult.isFeasible;
    row.validatedFeasible=logical(out.bestResult.isFeasible&&check.passed);
    row.firstSearchFeasibleFE=audit.firstSearchFeasibleFE;
    row.searchF=f;row.validationCV=check.CV;
    row.validationEnergyRelativeDifference=check.energyRelativeDifference;
    % Failed paths never become low-energy successes in aggregate statistics.
    if row.validatedFeasible
     row.energy=check.energy;row.F=check.F;row.length=check.length;row.flightTime=check.time;
    end
    row.status='complete';
    record=struct('protocolSignature',signature,'configuration',runCfg, ...
     'variant',V(vi),'environment',env,'bestZ',z,'convergence',conv, ...
     'output',out,'evaluationAudit',audit,'validation',check);
    tempFile=[tempname(runDir),'.mat'];save(tempFile,'record','-v7');
    recordFile=fullfile(runDir,'record.mat');
    [ok,msg]=movefile(tempFile,recordFile);if ~ok,error('paper:Move','%s',msg);end
    row.recordSHA256=paper_hash(recordFile,'file');
   catch ME
    row.status='error';row.errorId=ME.identifier;row.errorMessage=ME.message;
    fprintf('ERROR %s: %s\n',key,ME.message);
   end
   row.finished=datestr(now,30);
   paper_write_json(summaryFile,row);
   summaries(end+1)=normalize_summary(row,summaryTemplate);
   fprintf('%s %s FE=%g validated=%d\n',row.status,key,row.actualFEs,row.validatedFeasible);
  end
 end
end
paper_write_json(fullfile(batch,'run_summary.json'),summaries);
paper_export_summary(batch,summaries);
fprintf('Saved: %s\n',batch);
end
function r=empty_row(key,signature,candidate,variant,seed,cfg)
r=struct('runId',key,'signature',signature,'candidate',candidate,'variant',variant, ...
 'seedId',seed,'profile',cfg.paper.profile,'partition',cfg.paper.partition, ...
 'status','started','searchFeasible',false,'validatedFeasible',false, ...
 'actualFEs',NaN,'firstSearchFeasibleFE',NaN,'searchF',NaN,'validationCV',NaN, ...
 'validationEnergyRelativeDifference',NaN,'energy',NaN,'F',NaN,'length',NaN, ...
 'flightTime',NaN,'preparationSeconds',NaN,'searchSeconds',NaN,'validationSeconds',NaN, ...
 'environmentSHA256','','recordSHA256','','errorId','','errorMessage','','finished','');
end

function out=normalize_summary(in,template)
%NORMALIZE_SUMMARY Align resumed JSON rows with the current summary schema.
% JSON decoding and older versions may return fields in a different order or
% omit newly added fields.  Keep the immutable on-disk record unchanged and
% normalize only the in-memory aggregate used for run_summary exports.
out=template;
names=fieldnames(template);
for k=1:numel(names)
 if isfield(in,names{k}),out.(names{k})=in.(names{k});end
end
end
