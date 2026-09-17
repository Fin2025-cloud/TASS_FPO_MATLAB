function cfg = paper_config(profile)
%PAPER_CONFIG Reproducible protocol; formal mode is fail-closed.
if nargin<1, profile='smoke'; end
cfg=formal_experiment_config(profile);
cfg.experiment.release='2.0.0';
cfg.experiment.useParallel=false;
cfg.algorithm.verbose=false;
cfg.objective.weights.length=.35;
cfg.objective.weights.time=0;
cfg.strategy.selector='softmax';
cfg.strategy.creditMode='split';
cfg.strategy.costMode='actual';
cfg.strategy.fixedCost=1;
cfg.strategy.recordEvents=true;
cfg.paper=struct('protocol','TAAS-PAPER-2.0.0', ...
    'profile',char(profile),'block','main','partition','development', ...
    'candidateIds',{{'S2-B','S6-E'}},'seedIds',1:cfg.experiment.numRuns, ...
    'outputRoot',fullfile(paper_root(),'results','paper'), ...
    'resume',true,'validationFactor',4,'maxValidationPoints',4000, ...
    'attestationFile',fullfile(paper_root(),'config','study_attestation.json'));
% Physical model is explicitly a reference-model setting, not platform calibration.
cfg.energy.model='B';
cfg.paper.energyStatus='uncalibrated_reference_model';
cfg.environment.verifyGeoTIFFChecksum=true;
cfg.data.verifyChecksum=true;
end

