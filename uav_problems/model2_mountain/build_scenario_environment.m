function env = build_scenario_environment(cfg,scenarioId,seed)
%BUILD_SCENARIO_ENVIRONMENT 统一构造论文六类环境。
%
% 场景定义
% -------------------------------------------------------------------------
% S1 合成中等起伏、多山峰：基础规划和算法调试；
% S2 合成双山脊、三山口多拓扑通道：验证可行域搜索能力；
% S3 公开真实 DSM 平行山脊谷地：验证地形驱动的真实路径选择；
% S4 公开真实 DEM 山脊陡坡：验证复杂地形与静态禁飞区规避；
% S5 公开真实 DEM + 确定性空间风场：验证节能规划；
% S6 与 S5 同一 DEM/风场 + 可预测动态障碍：综合准动态实验。
%
% 真实性规则
% -------------------------------------------------------------------------
% 真实场景直接读取 data/dem/processed 中的 GeoTIFF。地形矩阵不进行平滑、
% 缩放或随机扰动。静态障碍、风场和动态障碍是独立的场景层，不会写回 DEM。

if nargin<2 || isempty(scenarioId), scenarioId=1; end
if nargin<3 || isempty(seed), seed=100000+1000*scenarioId; end
if ~isscalar(scenarioId) || ~ismember(scenarioId,1:6)
    error('build_scenario_environment:Scenario','scenarioId must be an integer from 1 to 6.');
end

if scenarioId<=2
    if scenarioId==1
        % S1 保留原有中等起伏多山峰环境，用于基础性能与回归比较。
        env = build_synthetic_environment(cfg,1,seed);
        env.id = 'S1';
        env.seed = seed;
        env.scenarioName = '合成中等起伏多山峰场景';
        env.wind = struct('type','constant','constant',[0 0 0]);
        env.dynamicObstacles = struct([]);
        env.meta.syntheticGeneratorLevel = 1;
    else
        % S2 使用专用的双屏障三山口生成器。山脊主体在计入最小净空后高于
        % 冻结 Z 上限，路径只能选择山口，避免旧版通过升高航迹直接越顶。
        env = build_multichannel_environment(cfg,seed);
    end
    env.meta.scenarioDefinition = mfilename;
    env.meta.isRealDEM = false;
    return;
end

item = dem_catalog(scenarioId);
modelDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(modelDir));
demFile = fullfile(projectRoot,item.relativeFile);

% 首次读取时先建立局部米制坐标。起终点使用固定比例，避免依赖优化结果。
options = struct();
options.useLocalCoordinates = true;
options.startFraction = item.startFraction;
options.goalFraction = item.goalFraction;
options.altitudeMargin = item.altitudeMargin;
options.zTopMargin = item.zTopMargin;
options.sourceDescription = item.sourceDescription;
options.scenarioName = item.scenarioName;
options.expectedSHA256 = item.expectedSHA256;
options.verifyChecksum = safe_nested(cfg,{'data','verifyChecksum'},true);
options.crs = item.crs;
options.nominalResolution = item.resolution;
options.noDataValue = item.noDataValue;
env = load_dem_environment(demFile,cfg,options);

env.id = sprintf('S%d',scenarioId);
env.seed = seed;
env.scenarioName = item.scenarioName;
env.meta.scenarioDefinition = mfilename;
env.meta.catalog = item;
env.meta.isRealDEM = true;

% 默认真实场景先不放置任何附加层，随后按 S4-S6 逐级增加复杂性。
env.staticObstacles = struct([]);
env.dynamicObstacles = struct([]);
env.wind = struct('type','constant','constant',[0 0 0]);

if scenarioId>=4
    % 圆柱用于表达通信塔或固定禁飞区；中心按地图比例定义，zMax 根据该点
    % 的真实地形高程确定，因此在不同绝对高程数据集上仍保持物理含义。
    env.staticObstacles = [ ...
        make_fractional_cylinder(env,[0.43 0.46],90,150,'restricted_zone_A'); ...
        make_fractional_cylinder(env,[0.68 0.64],110,170,'restricted_zone_B')];
end

if scenarioId>=5
    mapWidth = diff(env.xLim);
    mapHeight = diff(env.yLim);
    env.wind = struct();
    env.wind.type = 'terrain_composite';
    env.wind.base = [4.0,1.0,0.0];
    env.wind.shear = [0.003,-0.0015,0.0];
    env.wind.vortexCenter = [env.xLim(1)+0.55*mapWidth,env.yLim(1)+0.48*mapHeight];
    % wind_velocity 中涡旋幅度近似按 strength/r 衰减；该值产生约 0-1 m/s
    % 的局部附加水平风，不会改变 DEM 或路径几何约束。
    env.wind.vortexStrength = 1800;
    env.wind.verticalScale = 1.2;
end

if scenarioId==6
    env.scenarioName = '真实DEM风场与动态障碍综合场景';
    env.dynamicObstacles = [ ...
        make_fractional_dynamic(env,[0.24 0.68],[4.0 -2.0 0],10,2.0,0.025,'other_UAV_1'); ...
        make_fractional_dynamic(env,[0.76 0.34],[-3.5 2.5 0],11,2.5,0.030,'other_UAV_2'); ...
        make_fractional_dynamic(env,[0.55 0.88],[0 -4.0 0],8,2.0,0.035,'bird_group_3')];
end
end

function obstacle = make_fractional_cylinder(env,fraction,radius,heightAboveTerrain,name)
xy = fractional_xy(env,fraction);
baseH = terrain_height(env,xy(1),xy(2));
obstacle = struct('type','cylinder','center',xy,'radius',radius, ...
    'zMin',baseH,'zMax',baseH+heightAboveTerrain,'name',name);
end

function obstacle = make_fractional_dynamic(env,fraction,velocity,radius,sigma0,sigmaRate,name)
xy = fractional_xy(env,fraction);
baseH = terrain_height(env,xy(1),xy(2));
p0 = [xy,baseH+80];
obstacle = struct('p0',p0,'velocity',velocity,'radius',radius, ...
    'sigma0',sigma0,'sigmaRate',sigmaRate,'name',name);
end

function xy = fractional_xy(env,fraction)
xy = [env.xLim(1)+fraction(1)*diff(env.xLim), ...
      env.yLim(1)+fraction(2)*diff(env.yLim)];
end

function value = safe_nested(s,path,defaultValue)
value = defaultValue;
for k=1:numel(path)
    if ~isstruct(s) || ~isfield(s,path{k}), return; end
    s=s.(path{k});
end
value=s;
end
