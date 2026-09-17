function T = screen_environment_library(cfg,showTable)
%SCREEN_ENVIRONMENT_LIBRARY Build all candidates and return a sortable table.
if nargin<1||isempty(cfg),cfg=environment_config();end
if nargin<2,showTable=true;end
C=environment_catalog(); rows=cell(numel(C),1);
tic;
for k=1:numel(C)
    env=build_environment_candidate(C(k).id,cfg);
    rows{k}=compute_environment_metrics(env,cfg);
end
T=struct2table(vertcat(rows{:}));
T.name=string({C.name})'; T.description=string({C.description})'; T.recommended=[C.recommended]';
T=movevars(T,{'name','description','recommended'},'After','id');
root=fileparts(fileparts(mfilename('fullpath')));
writetable(T,fullfile(root,'results','environment_screening.csv'));
if showTable, disp(T(:,{'id','name','realDEM','reliefM','slopeP90Deg','directMinClearanceM','directViolationFraction','staticObstacleCount','windReferenceMps','dynamicObstacleCount','expectedRoutes','recommended'})); end
fprintf('Built and screened %d candidates in %.2f s. No optimizer was run.\n',height(T),toc);
end
