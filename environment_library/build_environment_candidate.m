function env = build_environment_candidate(candidateId,cfg)
%BUILD_ENVIRONMENT_CANDIDATE Build one deterministic candidate environment.
if nargin<2 || isempty(cfg), cfg=environment_config(); end
item=get_environment_candidate(candidateId);
if strcmpi(item.terrainType,'synthetic')
    env=build_synthetic_candidate(item,cfg);
else
    env=load_real_candidate(item,cfg);
end
env=apply_environment_layers(env,item,cfg);
env.id=item.id;
env.scenarioId=item.scenarioId;
env.scenarioName=sprintf('S%d-%s: %s',item.scenarioId,item.variant,item.name);
env.seed=item.seed;
env.meta.catalogItem=item;
env.meta.environmentLibraryVersion='1.2.0';
env.meta.isRealDEM=strcmpi(item.terrainType,'real');
env.meta.selectionStatus='candidate_not_formally_selected';
env=validate_environment_candidate(env,cfg);
end
