function env = visualize_environment_candidate(candidateId,cfg)
%VISUALIZE_ENVIRONMENT_CANDIDATE Build and draw one candidate; no optimization.
if nargin<2||isempty(cfg),cfg=environment_config();end
env=build_environment_candidate(candidateId,cfg);
f=figure('Color','w','Name',env.scenarioName); ax=axes(f);
mode='3d'; if env.scenarioId==2,mode='top';end
plot_environment_candidate(ax,env,cfg,mode);
metrics=compute_environment_metrics(env,cfg);
sgtitle(sprintf('%s | %s | direct-line min clearance %.1f m',env.scenarioName,env.meta.catalogItem.description,metrics.directMinClearanceM),'Interpreter','none');
end
