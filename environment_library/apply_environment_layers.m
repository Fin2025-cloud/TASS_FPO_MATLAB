function env = apply_environment_layers(env,item,cfg)
%APPLY_ENVIRONMENT_LAYERS Add static zones, deterministic wind and dynamics.
env.staticObstacles=make_static_preset(env,item.staticPreset);
env.wind=make_wind_preset(env,item.windPreset);
env.dynamicObstacles=make_dynamic_preset(env,item.dynamicPreset,cfg);
end

function obs=make_static_preset(env,preset)
sets=struct();
sets.none=zeros(0,4);
sets.sparse2=[.42 .46 .017 .20;.68 .64 .020 .23];
sets.cluster3=[.46 .42 .015 .18;.57 .55 .017 .22;.69 .48 .014 .19];
sets.offset3=[.34 .62 .018 .20;.55 .42 .020 .24;.73 .68 .018 .21];
sets.ridge3=[.37 .38 .017 .19;.58 .57 .019 .22;.75 .44 .016 .20];
sets.dense4=[.30 .35 .018 .18;.46 .60 .018 .21;.63 .38 .019 .20;.78 .66 .017 .19];
if ~isfield(sets,preset), error('apply_environment_layers:StaticPreset','Unknown %s.',preset); end
A=sets.(preset); obs=struct('type',{},'center',{},'radius',{},'zMin',{},'zMax',{},'name',{});
scale=min(diff(env.xLim),diff(env.yLim)); relief=max(env.terrain.Z(:))-min(env.terrain.Z(:));
for k=1:size(A,1)
    xy=fxy(env,A(k,1:2)); h=terrain_at(env,xy);
    obs(k)=struct('type','cylinder','center',xy,'radius',max(35,A(k,3)*scale), ...
        'zMin',h,'zMax',h+max(80,A(k,4)*max(relief,400)), ...
        'name',sprintf('%s_%d',preset,k)); %#ok<AGROW>
end
end

function wind=make_wind_preset(env,preset)
W=diff(env.xLim); H=diff(env.yLim);
switch preset
    case 'calm'
        wind=struct('type','constant','constant',[0 0 0]);
    case 'crosswind'
        wind=composite([4.5 1.5 0],[.0015 -.0005 0],[.58 .48],1600,.8);
    case 'valley_flow'
        wind=composite([1.5 5.0 0],[.0005 .0010 0],[.52 .55],1900,.7);
    case 'mountain_shear'
        wind=composite([4.0 -2.0 0],[.0040 -.0020 0],[.56 .48],2200,1.5);
    case 'mountain_rotor'
        wind=composite([3.0 1.0 0],[.0030 -.0015 0],[.52 .50],3000,1.7);
    case 'rotating_flow'
        wind=composite([2.0 2.0 0],[.0010 -.0010 0],[.50 .50],2600,1.0);
    otherwise
        error('apply_environment_layers:WindPreset','Unknown %s.',preset);
end
if strcmp(wind.type,'terrain_composite')
    wind.vortexCenter=[env.xLim(1)+wind.vortexCenterFraction(1)*W, ...
        env.yLim(1)+wind.vortexCenterFraction(2)*H];
    wind=rmfield(wind,'vortexCenterFraction');
end
end
function w=composite(base,shear,center,strength,vertical)
w=struct('type','terrain_composite','base',base,'shear',shear, ...
    'vortexCenterFraction',center,'vortexStrength',strength,'verticalScale',vertical);
end

function dyn=make_dynamic_preset(env,preset,cfg)
sets=struct();
sets.none=zeros(0,8);
sets.single_crossing=[.30 .70 70 4.5 -3.0 0 9 0.03];
sets.double_crossing=[.28 .72 75 4.0 -2.5 0 9 .03;.74 .30 85 -3.5 2.8 0 10 .035];
sets.opposing=[.25 .50 85 5.0 0 0 10 .03;.75 .52 90 -4.5 0 0 10 .03];
sets.triple_mixed=[.25 .70 80 4 -2 0 9 .03;.75 .35 90 -3 2.5 0 10 .035;.55 .88 75 0 -4 0 8 .04];
sets.bird_group=[.40 .75 65 2.5 -2.0 .2 12 .06;.68 .38 70 -2.0 2.2 .1 11 .055];
if ~isfield(sets,preset), error('apply_environment_layers:DynamicPreset','Unknown %s.',preset); end
A=sets.(preset); dyn=struct('p0',{},'velocity',{},'radius',{},'sigma0',{},'sigmaRate',{},'name',{});
for k=1:size(A,1)
    xy=fxy(env,A(k,1:2)); h=terrain_at(env,xy);
    dyn(k)=struct('p0',[xy,h+cfg.constraint.clearance+A(k,3)], ...
        'velocity',A(k,4:6),'radius',A(k,7),'sigma0',2.0, ...
        'sigmaRate',A(k,8),'name',sprintf('%s_%d',preset,k)); %#ok<AGROW>
end
end
function xy=fxy(env,f), xy=[env.xLim(1)+f(1)*diff(env.xLim),env.yLim(1)+f(2)*diff(env.yLim)]; end
function h=terrain_at(env,xy), h=interp2(env.terrain.x,env.terrain.y,env.terrain.Z,xy(1),xy(2),'linear'); end
