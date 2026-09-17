function ids = visualize_selected_environments(cfg)
%VISUALIZE_SELECTED_ENVIRONMENTS 展示选项5保存的六个环境，不运行算法。
if nargin<1||isempty(cfg),cfg=environment_config();end
ids=load_environment_selection(cfg);
compare_selected_environments(ids,cfg);
end
