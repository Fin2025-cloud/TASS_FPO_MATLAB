function report=paper_preflight(cfg,V)
%PAPER_PREFLIGHT No optimizer is executed. Pending checks block formal runs.
if nargin<1,cfg=paper_config('formal');end
if nargin<2,V=paper_variants(cfg.paper.block);end
validate_config(cfg);
assert(ischar(cfg.paper.partition)&&any(strcmp(cfg.paper.partition,{'development','test'})), ...
 'paper:Partition','Partition must be development or test.');
assert(~isempty(cfg.paper.seedIds)&&all(isfinite(cfg.paper.seedIds))&& ...
 all(cfg.paper.seedIds>=1)&&all(cfg.paper.seedIds==fix(cfg.paper.seedIds)), ...
 'paper:Seeds','Seed IDs must be positive integers.');
assert(numel(unique(cfg.paper.seedIds))==numel(cfg.paper.seedIds),'paper:Seeds','Duplicate seeds.');
assert(numel(unique(cfg.paper.candidateIds))==numel(cfg.paper.candidateIds),'paper:Instances','Duplicate instances.');
assert(cfg.paper.validationFactor>=2&&cfg.paper.maxValidationPoints>=cfg.path.maxAdaptivePoints, ...
 'paper:Validation','Terminal validation must not be coarser.');
for k=1:numel(cfg.paper.candidateIds),get_environment_candidate(cfg.paper.candidateIds{k});end
code=paper_code_manifest();
signature=paper_protocol_signature(cfg,V,code);
pending={};
a=struct();
if isfile(cfg.paper.attestationFile),a=jsondecode(fileread(cfg.paper.attestationFile));end
checks={'energy_parameters_reviewed','fpo_reference_reviewed','data_split_reviewed', ...
 'analysis_plan_reviewed','matlab_tests_passed','modern_baselines_reviewed'};
for k=1:numel(checks)
 if ~isfield(a,checks{k})||~isequal(a.(checks{k}),true),pending{end+1}=checks{k};end
end
if ~isfield(a,'reviewer')||isempty(strtrim(a.reviewer)),pending{end+1}='named_human_reviewer';end
if ~isfield(a,'protocol_sha256')||~strcmp(a.protocol_sha256,signature),pending{end+1}='protocol_signature_not_approved';end
if ~strcmp(cfg.paper.partition,'test'),pending{end+1}='test_partition_not_selected';end
if numel(cfg.paper.seedIds)<30,pending{end+1}='fewer_than_30_test_seeds';end
if exist('OCTAVE_VERSION','builtin'),pending{end+1}='current_runtime_is_not_MATLAB';end
if strcmp(cfg.paper.energyStatus,'uncalibrated_reference_model')
 pending{end+1}='energy_model_source_or_calibration_not_frozen';
end
report=struct('protocolSHA256',signature,'codeSHA256',code.sha256, ...
 'pending',{pending},'formalAllowed',isempty(pending),'runtime',version, ...
 'implementation','MATLAB source; Octave execution is not MATLAB verification');
if strcmp(cfg.paper.profile,'formal')&&~report.formalAllowed
 disp(report);
 error('paper:FormalBlocked','Formal run blocked. Complete named review and approve this protocol hash.');
end
end
