function env = validate_environment_candidate(env,cfg)
%VALIDATE_ENVIRONMENT_CANDIDATE Fast structural and physical checks.
required={'id','xLim','yLim','zLim','terrain','start','goal','wind','staticObstacles','dynamicObstacles'};
for k=1:numel(required)
    if ~isfield(env,required{k}), error('validate_environment_candidate:Missing','Missing env.%s.',required{k}); end
end
x=env.terrain.x(:); y=env.terrain.y(:); Z=env.terrain.Z;
if size(Z,1)~=numel(y) || size(Z,2)~=numel(x), error('validate_environment_candidate:Grid','Terrain grid size mismatch.'); end
if any(diff(x)<=0)||any(diff(y)<=0)||any(~isfinite(Z(:))), error('validate_environment_candidate:Terrain','Terrain must be finite with increasing axes.'); end
for p=[env.start;env.goal]'
    if p(1)<env.xLim(1)||p(1)>env.xLim(2)||p(2)<env.yLim(1)||p(2)>env.yLim(2), error('validate_environment_candidate:Endpoint','Endpoint outside map.'); end
end
hs=interp2(x,y,Z,env.start(1),env.start(2),'linear');
hg=interp2(x,y,Z,env.goal(1),env.goal(2),'linear');
if env.start(3)<hs+cfg.constraint.clearance || env.goal(3)<hg+cfg.constraint.clearance
    error('validate_environment_candidate:Clearance','Start or goal violates minimum terrain clearance.');
end
env.meta.validation='passed';
end
