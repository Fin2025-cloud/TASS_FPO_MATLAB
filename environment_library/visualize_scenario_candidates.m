function envs = visualize_scenario_candidates(scenarioId,cfg)
%VISUALIZE_SCENARIO_CANDIDATES Show five alternatives for one scenario.
if nargin<2||isempty(cfg),cfg=environment_config();end
if ~isscalar(scenarioId)||~ismember(scenarioId,1:6),error('Scenario must be 1-6.');end
C=environment_catalog(); C=C([C.scenarioId]==scenarioId); envs=cell(numel(C),1);
f=figure('Color','w','Name',sprintf('S%d candidate library',scenarioId));
t=tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
for k=1:numel(C)
    envs{k}=build_environment_candidate(C(k).id,cfg); ax=nexttile(t);
    mode='3d'; if scenarioId==2,mode='top';end
    plot_environment_candidate(ax,envs{k},cfg,mode);
    title(ax,sprintf('%s  %s',C(k).id,C(k).name),'Interpreter','none','FontSize',10);
end
ax=nexttile(t); axis(ax,'off');
text(ax,0,.95,sprintf('S%d candidate notes',scenarioId),'FontWeight','bold','VerticalAlignment','top');
for k=1:numel(C), text(ax,0,.88-.15*(k-1),sprintf('%s: %s',C(k).id,C(k).description),'VerticalAlignment','top','Interpreter','none'); end
sgtitle(t,sprintf('Scenario S%d: five fast-preview candidates (no optimizer)',scenarioId));
end
