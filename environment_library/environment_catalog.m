function C = environment_catalog()
%ENVIRONMENT_CATALOG Thirty deterministic candidates: five for each S1-S6.
% Add or remove candidates here without changing the terrain/evaluator code.
t = struct('id','','scenarioId',0,'variant','','name','','terrainType','', ...
    'terrainKey','','recipe','','seed',0,'startFraction',[0 0], ...
    'goalFraction',[1 1],'altitudeMargin',15,'zTopMargin',80, ...
    'staticPreset','none','windPreset','calm','dynamicPreset','none', ...
    'expectedRoutes',1,'description','','recommended',false);
C = repmat(t,0,1);

% S1: natural-looking synthetic mountain terrain, no added obstacle layers.
C(end+1)=item(t,'S1-A',1,'A','Rolling foothills','synthetic','','rolling',1101,[.05 .15],[.94 .82],18,100,'none','calm','none',2,'Smooth low-to-medium relief and broad terrain choices.',false);
C(end+1)=item(t,'S1-B',1,'B','Scattered mountain groups','synthetic','','peaks',1102,[.05 .82],[.94 .18],18,100,'none','calm','none',3,'Several anisotropic mountain groups with open gaps.',true);
C(end+1)=item(t,'S1-C',1,'C','Ridge and basin','synthetic','','ridge_basin',1103,[.07 .12],[.93 .88],18,90,'none','calm','none',2,'A curved ridge surrounds a shallow basin.',false);
C(end+1)=item(t,'S1-D',1,'D','Twin peaks and saddle','synthetic','','saddle',1104,[.07 .75],[.93 .25],18,90,'none','calm','none',2,'Two dominant peaks separated by a natural saddle.',false);
C(end+1)=item(t,'S1-E',1,'E','Asymmetric upland','synthetic','','upland',1105,[.05 .25],[.95 .75],18,95,'none','calm','none',2,'Sloping upland, oblique ridge and side valley.',false);

% S2: natural multiple-route terrain. No vertical artificial wall or cylinders.
C(end+1)=item(t,'S2-A',2,'A','Braided valley network','synthetic','','braided_valleys',1201,[.05 .16],[.95 .84],15,70,'none','calm','none',3,'Three smooth, merging valley corridors carved in an upland.',true);
C(end+1)=item(t,'S2-B',2,'B','Staggered mountain passes','synthetic','','staggered_passes',1202,[.05 .50],[.95 .50],15,70,'none','calm','none',3,'Two broad natural ridges with offset saddles.',false);
C(end+1)=item(t,'S2-C',2,'C','Forked canyon system','synthetic','','canyon_forks',1203,[.08 .10],[.92 .90],15,75,'none','calm','none',3,'A Y-shaped canyon system provides alternative branches.',false);
C(end+1)=item(t,'S2-D',2,'D','Mountain basin exits','synthetic','','basin_exits',1204,[.50 .08],[.50 .92],15,70,'none','calm','none',4,'A central basin with four naturally lowered exits.',false);
C(end+1)=item(t,'S2-E',2,'E','Interlocking ridge network','synthetic','','ridge_network',1205,[.07 .82],[.93 .18],15,75,'none','calm','none',3,'Curved intersecting ridges leave several non-equivalent corridors.',false);

% S3: real public DSM without additional obstacles or wind.
C(end+1)=item(t,'S3-A',3,'A','Real parallel-ridge corridor','real','R1','',1301,[.05 .22],[.95 .72],12,80,'none','calm','none',3,'Featured Appalachian parallel-ridge real terrain.',true);
C(end+1)=item(t,'S3-B',3,'B','Real dissected plateau','real','R5','',1302,[.05 .15],[.95 .82],15,90,'none','calm','none',3,'Moderate relief with dense natural valley structure.',false);
C(end+1)=item(t,'S3-C',3,'C','Real mild rolling reference','real','R4','',1303,[.06 .25],[.94 .75],15,60,'none','calm','none',1,'Easy real-data reference; not recommended as the sole real scene.',false);
C(end+1)=item(t,'S3-D',3,'D','Real Sierra cross-slope','real','R2','',1304,[.06 .88],[.94 .12],12,100,'none','calm','none',2,'Large relief and steep cross-slope route.',false);
C(end+1)=item(t,'S3-E',3,'E','Real Altai valley crossing','real','R3','',1305,[.05 .14],[.95 .78],12,90,'none','calm','none',2,'High-mountain valley and surrounding peaks.',false);

% S4: real terrain plus deterministic static restricted zones.
C(end+1)=item(t,'S4-A',4,'A','Appalachian restricted corridors','real','R1','',1401,[.05 .18],[.95 .78],12,85,'sparse2','calm','none',3,'Parallel ridges plus two terrain-relative restricted zones.',false);
C(end+1)=item(t,'S4-B',4,'B','Plateau tower cluster','real','R5','',1402,[.05 .20],[.95 .80],15,90,'cluster3','calm','none',3,'Dissected plateau plus three fixed tower/no-fly cylinders.',false);
C(end+1)=item(t,'S4-C',4,'C','Sierra offset restrictions','real','R2','',1403,[.05 .88],[.95 .12],12,100,'offset3','calm','none',2,'Steep relief with restrictions placed off the direct line.',true);
C(end+1)=item(t,'S4-D',4,'D','Altai ridge-side restrictions','real','R3','',1404,[.05 .16],[.95 .78],12,95,'ridge3','calm','none',2,'High mountain terrain with three ridge-side restricted zones.',false);
C(end+1)=item(t,'S4-E',4,'E','Mild terrain dense obstacles','real','R4','',1405,[.05 .20],[.95 .80],15,65,'dense4','calm','none',3,'Low terrain complexity but higher static-obstacle density.',false);

% S5: real terrain plus deterministic wind, no dynamic obstacle.
C(end+1)=item(t,'S5-A',5,'A','Appalachian crosswind','real','R1','',1501,[.05 .22],[.95 .72],12,85,'sparse2','crosswind','none',3,'Parallel ridges under a diagonal crosswind and weak shear.',false);
C(end+1)=item(t,'S5-B',5,'B','Plateau valley-flow wind','real','R5','',1502,[.05 .16],[.95 .84],15,90,'cluster3','valley_flow','none',3,'Terrain-composite flow aligned with the main valley direction.',false);
C(end+1)=item(t,'S5-C',5,'C','Sierra vertical shear','real','R2','',1503,[.05 .88],[.95 .12],12,105,'offset3','mountain_shear','none',2,'Strong height-dependent cross-slope wind in steep relief.',false);
C(end+1)=item(t,'S5-D',5,'D','Altai mountain rotor','real','R3','',1504,[.05 .16],[.95 .78],12,95,'ridge3','mountain_rotor','none',2,'High-relief terrain with shear, weak rotor and vertical component.',true);
C(end+1)=item(t,'S5-E',5,'E','Mild terrain rotating flow','real','R4','',1505,[.05 .20],[.95 .80],15,65,'dense4','rotating_flow','none',2,'Easy terrain isolates wind-field effects.',false);

% S6: real terrain, static zones, wind and predictable dynamic obstacles.
C(end+1)=item(t,'S6-A',6,'A','Appalachian single crossing UAV','real','R1','',1601,[.05 .22],[.95 .72],12,85,'sparse2','crosswind','single_crossing',3,'One predictable crossing aircraft in a ridge corridor.',false);
C(end+1)=item(t,'S6-B',6,'B','Plateau dual traffic','real','R5','',1602,[.05 .16],[.95 .84],15,90,'cluster3','valley_flow','double_crossing',3,'Two predictable moving obstacles in branching valleys.',false);
C(end+1)=item(t,'S6-C',6,'C','Sierra opposing traffic','real','R2','',1603,[.05 .88],[.95 .12],12,105,'offset3','mountain_shear','opposing',2,'Steep cross-slope route with opposing predicted traffic.',false);
C(end+1)=item(t,'S6-D',6,'D','Altai mixed dynamic traffic','real','R3','',1604,[.05 .16],[.95 .78],12,95,'ridge3','mountain_rotor','triple_mixed',2,'High mountain composite scene with three moving obstacles.',true);
C(end+1)=item(t,'S6-E',6,'E','Mild terrain bird group','real','R4','',1605,[.05 .20],[.95 .80],15,65,'dense4','rotating_flow','bird_group',2,'Mild terrain focuses on wind and uncertain bird-group motion.',false);
end

function x=item(x,id,s,v,name,terrainType,terrainKey,recipe,seed,startF,goalF,alt,zTop,staticP,windP,dynP,routes,desc,recommended)
x.id=id; x.scenarioId=s; x.variant=v; x.name=name; x.terrainType=terrainType;
x.terrainKey=terrainKey; x.recipe=recipe; x.seed=seed; x.startFraction=startF;
x.goalFraction=goalF; x.altitudeMargin=alt; x.zTopMargin=zTop;
x.staticPreset=staticP; x.windPreset=windP; x.dynamicPreset=dynP;
x.expectedRoutes=routes; x.description=desc; x.recommended=recommended;
end
