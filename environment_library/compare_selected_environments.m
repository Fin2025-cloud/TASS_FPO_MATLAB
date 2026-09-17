function envs = compare_selected_environments(ids,cfg)
%COMPARE_SELECTED_ENVIRONMENTS Draw one candidate for each S1-S6.
if nargin<1||isempty(ids),ids=default_environment_selection();end
if nargin<2||isempty(cfg),cfg=environment_config();end
if numel(ids)~=6,error('Exactly six IDs are required.');end
envs=cell(6,1); f=figure('Color','w','Name','Selected environment comparison');
t=tiledlayout(f,2,3,'TileSpacing','compact','Padding','compact');
for s=1:6
    envs{s}=build_environment_candidate(ids{s},cfg); ax=nexttile(t);
    mode='3d'; if s==2,mode='top';end
    plot_environment_candidate(ax,envs{s},cfg,mode);
end
sgtitle(t,'Provisional S1-S6 selection — environment inspection only');
end
