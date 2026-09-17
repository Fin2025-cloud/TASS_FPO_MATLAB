function env = build_synthetic_candidate(item,cfg)
%BUILD_SYNTHETIC_CANDIDATE Natural-looking deterministic synthetic terrain.
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(item.seed,'twister');
mapSize=cfg.environment.syntheticMapSize;
gridSize=cfg.environment.syntheticGridSize;
x=linspace(0,mapSize(1),gridSize(1));
y=linspace(0,mapSize(2),gridSize(2));
[X,Y]=meshgrid(x,y); xn=X/mapSize(1); yn=Y/mapSize(2);
noise=fractal_noise_2d(numel(y),numel(x),item.seed);

switch lower(item.recipe)
    case 'rolling'
        Z=45+35*sin(1.5*pi*xn).*cos(1.2*pi*yn)+25*sin(2*pi*(xn+.25*yn));
        Z=Z+gauss2(xn,yn,.28,.35,95,.18,.22,15)+gauss2(xn,yn,.72,.62,120,.22,.18,-20);
    case 'peaks'
        Z=35+18*sin(2*pi*xn).*cos(1.4*pi*yn);
        P=[.25 .28 150 .11 .15 18;.48 .70 190 .13 .12 -22;.72 .35 170 .14 .10 35;.82 .78 125 .12 .16 -10];
        for k=1:size(P,1), Z=Z+gauss2(xn,yn,P(k,1),P(k,2),P(k,3),P(k,4),P(k,5),P(k,6)); end
    case 'ridge_basin'
        ridge=145*exp(-0.5*((sqrt(((xn-.52)/.42).^2+((yn-.53)/.34).^2)-1)/.16).^2);
        basin=-55*exp(-0.5*(((xn-.53)/.25).^2+((yn-.52)/.22).^2));
        Z=45+ridge+basin+35*sin(2*pi*xn).*sin(1.5*pi*yn);
    case 'saddle'
        Z=35+gauss2(xn,yn,.42,.50,210,.18,.20,10)+gauss2(xn,yn,.66,.52,190,.17,.19,-12);
        Z=Z-65*exp(-0.5*(((xn-.54)/.10).^2+((yn-.51)/.20).^2));
    case 'upland'
        Z=35+120*xn+95*exp(-0.5*((yn-(.25+.45*xn))/.10).^2);
        Z=Z-55*exp(-0.5*((yn-(.78-.35*xn))/.12).^2)+35*sin(2*pi*xn).*cos(2*pi*yn);
    case 'braided_valleys'
        Z=235+80*xn+45*sin(pi*yn)+25*noise;
        routes={ [.02 .15;.30 .28;.58 .48;.98 .84], [.02 .15;.28 .48;.65 .58;.98 .84], [.02 .15;.35 .70;.68 .72;.98 .84] };
        for k=1:numel(routes), Z=Z-145*exp(-(polyline_distance(xn,yn,routes{k})/.070).^2); end
        Z=Z+60*exp(-0.5*(((xn-.52)/.22).^2+((yn-.50)/.24).^2));
    case 'staggered_passes'
        Z=55+25*noise;
        r1=175*exp(-0.5*((xn-.37)/.075).^2).*(.70+.30*cos(pi*(yn-.5)));
        r2=180*exp(-0.5*((xn-.68)/.080).^2).*(.70+.30*cos(pi*(yn-.5)));
        gates1=1-.75*exp(-0.5*((yn-.25)/.07).^2)-.70*exp(-0.5*((yn-.55)/.08).^2)-.72*exp(-0.5*((yn-.82)/.07).^2);
        gates2=1-.72*exp(-0.5*((yn-.18)/.07).^2)-.78*exp(-0.5*((yn-.48)/.08).^2)-.70*exp(-0.5*((yn-.75)/.07).^2);
        Z=Z+r1.*max(gates1,.12)+r2.*max(gates2,.12)+30*sin(2*pi*yn);
    case 'canyon_forks'
        Z=250+65*xn+30*noise;
        trunk=[.05 .10;.35 .34;.52 .50];
        b1=[.52 .50;.72 .67;.95 .90]; b2=[.52 .50;.76 .43;.95 .90]; b3=[.52 .50;.70 .82;.95 .90];
        for q={trunk,b1,b2,b3}, Z=Z-155*exp(-(polyline_distance(xn,yn,q{1})/.065).^2); end
        Z=Z+35*sin(3*pi*xn).*cos(2*pi*yn);
    case 'basin_exits'
        r=sqrt(((xn-.5)/.43).^2+((yn-.5)/.38).^2);
        ring=190*exp(-0.5*((r-1)/.14).^2);
        angle=atan2(yn-.5,xn-.5);
        notch=ones(size(r));
        for a=[-2.4,-.8,.75,2.25], notch=notch.*(1-.72*exp(-0.5*(wrap_angle(angle-a)/.16).^2)); end
        Z=55+ring.*max(notch,.15)-45*exp(-0.5*(((xn-.5)/.25).^2+((yn-.5)/.22).^2))+22*noise;
    case 'ridge_network'
        Z=55+25*noise;
        ridges={ [.05 .28;.32 .40;.62 .34;.96 .20], [.08 .72;.38 .60;.68 .70;.95 .82], [.30 .04;.48 .42;.66 .96] };
        for k=1:numel(ridges), Z=Z+135*exp(-(polyline_distance(xn,yn,ridges{k})/.075).^2); end
        valleys={ [.04 .82;.42 .55;.96 .18], [.06 .15;.45 .48;.95 .75] };
        for k=1:numel(valleys), Z=Z-70*exp(-(polyline_distance(xn,yn,valleys{k})/.060).^2); end
    otherwise
        error('build_synthetic_candidate:Recipe','Unknown recipe %s.',item.recipe);
end
Z=Z+12*noise;
Z=Z-min(Z(:))+20;

env=struct(); env.xLim=[x(1),x(end)]; env.yLim=[y(1),y(end)];
env.terrain=struct('x',x,'y',y,'Z',Z,'source','synthetic', ...
    'dataModel','deterministic synthetic terrain','recipe',item.recipe);
env.zLim=[min(Z(:)),max(Z(:))+item.zTopMargin];
startXY=fractional_xy(env,item.startFraction); goalXY=fractional_xy(env,item.goalFraction);
startH=interp2(x,y,Z,startXY(1),startXY(2),'linear');
goalH=interp2(x,y,Z,goalXY(1),goalXY(2),'linear');
env.start=[startXY,startH+cfg.constraint.clearance+item.altitudeMargin];
env.goal=[goalXY,goalH+cfg.constraint.clearance+item.altitudeMargin];
env.staticObstacles=struct([]); env.dynamicObstacles=struct([]);
env.wind=struct('type','constant','constant',[0 0 0]);
env.meta=struct('terrainSource','synthetic','terrainModification','not_applicable', ...
    'generator',mfilename,'recipe',item.recipe);
end

function Z=gauss2(x,y,cx,cy,a,sx,sy,thetaDeg)
t=thetaDeg*pi/180; dx=x-cx; dy=y-cy;
u=cos(t)*dx+sin(t)*dy; v=-sin(t)*dx+cos(t)*dy;
Z=a*exp(-0.5*((u/sx).^2+(v/sy).^2));
end
function A=wrap_angle(A), A=atan2(sin(A),cos(A)); end
function xy=fractional_xy(env,f)
xy=[env.xLim(1)+f(1)*diff(env.xLim),env.yLim(1)+f(2)*diff(env.yLim)];
end
