function m = compute_environment_metrics(env,cfg)
%COMPUTE_ENVIRONMENT_METRICS Fast metrics for selecting scenes before optimization.
Z=double(env.terrain.Z); x=double(env.terrain.x); y=double(env.terrain.y);
dx=median(diff(x)); dy=median(diff(y));
[dZdy,dZdx]=gradient(Z,dy,dx); slope=atan(hypot(dZdx,dZdy));
rough=movstd(Z,5,0,1); rough=movstd(rough,5,0,2);

n=300; t=linspace(0,1,n)'; P=env.start+(env.goal-env.start).*t;
h=interp2(x,y,Z,P(:,1),P(:,2),'linear',NaN); clearance=P(:,3)-h;

m=struct(); m.id=env.id; m.scenarioId=env.scenarioId;
m.realDEM=double(env.meta.isRealDEM); m.reliefM=max(Z(:))-min(Z(:));
slopeDeg=sort(slope(:)*180/pi); idx=max(1,min(numel(slopeDeg),ceil(.90*numel(slopeDeg))));
m.slopeP90Deg=slopeDeg(idx); m.slopeMaxDeg=max(slopeDeg);
m.roughnessMeanM=mean(rough(:)); m.directMinClearanceM=min(clearance);
m.directViolationFraction=mean(clearance<cfg.constraint.clearance);
m.staticObstacleCount=numel(env.staticObstacles); m.dynamicObstacleCount=numel(env.dynamicObstacles);
m.windReferenceMps=reference_wind_speed(env);
m.mapWidthM=diff(env.xLim); m.mapHeightM=diff(env.yLim);
m.startGoalDistanceM=norm(env.goal-env.start);
m.expectedRoutes=env.meta.catalogItem.expectedRoutes;
end
function v=reference_wind_speed(env)
if strcmpi(env.wind.type,'constant'), v=norm(env.wind.constant);
else, v=norm(env.wind.base); end
end
