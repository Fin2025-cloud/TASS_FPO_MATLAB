function env = load_dem_environment(geoTiffFile,cfg,options)
%LOAD_DEM_ENVIRONMENT 从投影 GeoTIFF 构建可审计的真实地形环境。
%
% 输入
% -------------------------------------------------------------------------
% geoTiffFile : 已投影到米制平面坐标的单波段高程 GeoTIFF；
% cfg         : default_config 返回的完整配置；
% options     : 可选结构体，支持：
%   useLocalCoordinates  - true 时把世界坐标平移为从 0 附近开始的局部坐标；
%   startFraction/goalFraction - 起终点在局部范围内的固定比例 [fx,fy]；
%   startXY/goalXY       - 直接给定局部坐标时优先于比例；
%   altitudeMargin      - 起终点相对最小净空的附加高度[m]；
%   zTopMargin          - 地形最高点以上允许的搜索高度[m]；
%   expectedSHA256      - 冻结的数据文件摘要；
%   verifyChecksum      - 是否在加载时核验摘要；
%   sourceDescription、scenarioName、crs、nominalResolution。
%
% 数据处理原则
% -------------------------------------------------------------------------
% 1. 不对高程做平滑、缩放或归一化；
% 2. GeoTIFF NoData 先转换为 NaN，并在搜索用 Z 中仅做最近有效值填补；
% 3. 未填补的 Zraw 同时保留，最终路径可由 verify_path_on_raw_dem 独立复核；
% 4. 世界坐标到局部坐标只做平移，不旋转、不缩放，单位仍为米；
% 5. 像元坐标采用像元中心，避免半像元系统偏差。

if nargin<3 || isempty(options), options=struct(); end
if ~isfile(geoTiffFile)
    error('load_dem_environment:FileNotFound','DEM file not found: %s',geoTiffFile);
end

verifyChecksum = safe_field(options,'verifyChecksum',false);
expectedHash = char(string(safe_field(options,'expectedSHA256','')));
actualHash = '';
if verifyChecksum || ~isempty(expectedHash)
    actualHash = sha256_file(geoTiffFile);
end
if verifyChecksum && ~isempty(expectedHash) && ~strcmpi(actualHash,expectedHash)
    error('load_dem_environment:ChecksumMismatch', ...
        'DEM SHA-256 mismatch. Expected %s, received %s.',expectedHash,actualHash);
end

try
    [Z,R] = readgeoraster(geoTiffFile,'OutputType','double');
catch ME
    error('load_dem_environment:ReadFailed', ...
        ['readgeoraster failed. A supported projected GeoTIFF and MATLAB ' ...
         'Mapping Toolbox are required. Original error: %s'],ME.message);
end
Z=squeeze(Z);
if ndims(Z)~=2
    error('load_dem_environment:InvalidRaster','DEM must be a single-band 2-D raster.');
end

% 尝试从 GeoTIFF 元数据中读取 NoData 和 CRS。不同 MATLAB 版本的属性名称
% 略有差异，因此所有元数据读取均带有防御性分支，不影响核心高程读取。
info=[];
try
    info=georasterinfo(geoTiffFile);
catch
    % 旧版本没有 georasterinfo 时仍可依靠 readgeoraster 返回的参考对象运行。
end
noDataValues=[];
if ~isempty(info)
    try
        noDataValues=double(info.MissingDataIndicator(:));
    catch
    end
end
if isfield(options,'noDataValue')
    noDataValues=[noDataValues;double(options.noDataValue(:))]; %#ok<AGROW>
end
for k=1:numel(noDataValues)
    if isfinite(noDataValues(k))
        Z(Z==noDataValues(k))=NaN;
    end
end
% 某些 Float32 栅格以约 -3.4e38 表示 NoData，但元数据读取器可能未暴露该值。
Z(Z < -1e30)=NaN;
Z(~isfinite(Z))=NaN;

% 仅接受平面世界坐标。经纬度栅格必须在数据准备阶段显式投影，避免把角度
% 错当成米并污染距离、曲率、速度和能耗。
if isprop(R,'XWorldLimits') && isprop(R,'YWorldLimits')
    if isprop(R,'CellExtentInWorldX') && isprop(R,'CellExtentInWorldY')
        dx=double(R.CellExtentInWorldX);
        dy=double(R.CellExtentInWorldY);
        xWorld=double(R.XWorldLimits(1))+(0.5:(size(Z,2)-0.5))*dx;
        yWorld=double(R.YWorldLimits(2))-(0.5:(size(Z,1)-0.5))*dy;
    else
        xWorld=linspace(double(R.XWorldLimits(1)),double(R.XWorldLimits(2)),size(Z,2));
        yWorld=linspace(double(R.YWorldLimits(2)),double(R.YWorldLimits(1)),size(Z,1));
        dx=median(abs(diff(xWorld)));
        dy=median(abs(diff(yWorld)));
    end
elseif isprop(R,'LongitudeLimits')
    error('load_dem_environment:GeographicCoordinates', ...
        ['The raster uses longitude/latitude. Reproject it to a metre-based ' ...
         'CRS such as UTM before optimization.']);
else
    error('load_dem_environment:UnknownReference','Unsupported raster reference object.');
end

% interp2/griddedInterpolant 都要求网格向量严格递增。GeoTIFF 行通常从北向南，
% 因此将 y 和 Z 同步翻转；高程值与地理位置的对应关系保持不变。
if xWorld(2)<xWorld(1)
    xWorld=fliplr(xWorld);
    Z=fliplr(Z);
end
if yWorld(2)<yWorld(1)
    yWorld=fliplr(yWorld);
    Z=flipud(Z);
end

Zraw=Z;
missingMask=isnan(Zraw);
missingCount=nnz(missingMask);
if missingCount==numel(Zraw)
    error('load_dem_environment:AllMissing','DEM contains no valid elevation samples.');
end

% 搜索用栅格只对明确的空洞执行最近方向填补；不改变任何已有有效像元。
if missingCount>0
    Z=fillmissing(Z,'nearest',1);
    Z=fillmissing(Z,'nearest',2);
    if any(isnan(Z(:)))
        error('load_dem_environment:FillFailed','Unable to fill all DEM NoData cells.');
    end
end

useLocal=safe_field(options,'useLocalCoordinates',true);
if useLocal
    origin=[min(xWorld),min(yWorld)];
    x=xWorld-origin(1);
    y=yWorld-origin(2);
else
    origin=[0 0];
    x=xWorld;
    y=yWorld;
end

minZ=min(Z(:));
maxZ=max(Z(:));
zTopMargin=safe_field(options,'zTopMargin',300);
env=struct();
env.id='REAL_DEM';
env.seed=NaN;
env.xLim=[min(x),max(x)];
env.yLim=[min(y),max(y)];
env.zLim=safe_field(options,'zLim',[minZ,maxZ+zTopMargin]);

env.terrain=struct();
env.terrain.x=x;
env.terrain.y=y;
env.terrain.Z=Z;
env.terrain.Zraw=Zraw;
env.terrain.xWorld=xWorld;
env.terrain.yWorld=yWorld;
env.terrain.originWorld=origin;
env.terrain.source=geoTiffFile;
env.terrain.description=safe_field(options,'sourceDescription',geoTiffFile);
env.terrain.sha256=actualHash;
env.terrain.expectedSHA256=expectedHash;
env.terrain.checksumVerified=verifyChecksum && strcmpi(actualHash,expectedHash);
env.terrain.crs=safe_field(options,'crs',read_crs_text(info));
env.terrain.resolution=[dx dy];
env.terrain.nominalResolution=safe_field(options,'nominalResolution',[dx dy]);
env.terrain.noDataValues=noDataValues;
env.terrain.missingCellCount=missingCount;
env.terrain.missingFraction=missingCount/numel(Zraw);
env.terrain.processing='No smoothing/scaling; local coordinate translation; nearest fill only for explicit NoData in search copy.';

startFraction=safe_field(options,'startFraction',[0.05 0.05]);
goalFraction=safe_field(options,'goalFraction',[0.95 0.95]);
startDefault=[env.xLim(1)+startFraction(1)*diff(env.xLim), ...
              env.yLim(1)+startFraction(2)*diff(env.yLim)];
goalDefault=[env.xLim(1)+goalFraction(1)*diff(env.xLim), ...
             env.yLim(1)+goalFraction(2)*diff(env.yLim)];
startXY=safe_field(options,'startXY',startDefault);
goalXY=safe_field(options,'goalXY',goalDefault);
assert_inside(startXY,env,'startXY');
assert_inside(goalXY,env,'goalXY');

altitudeMargin=safe_field(options,'altitudeMargin',25);
startH=terrain_height(env,startXY(1),startXY(2));
goalH=terrain_height(env,goalXY(1),goalXY(2));
if ~isfinite(startH) || ~isfinite(goalH)
    error('load_dem_environment:StartGoalNoData','Start or goal lies over unresolved NoData.');
end
env.start=[startXY,startH+cfg.constraint.clearance+altitudeMargin];
env.goal=[goalXY,goalH+cfg.constraint.clearance+altitudeMargin];
env.staticObstacles=safe_field(options,'staticObstacles',struct([]));
env.dynamicObstacles=safe_field(options,'dynamicObstacles',struct([]));
env.wind=safe_field(options,'wind',struct('type','constant','constant',[0 0 0]));
env.scenarioName=safe_field(options,'scenarioName','真实DEM场景');
env.meta=struct('generator',mfilename,'isRealDEM',true,'sourceFile',geoTiffFile, ...
    'useLocalCoordinates',useLocal,'worldOrigin',origin,'checksumVerified',env.terrain.checksumVerified);
end

function assert_inside(xy,env,name)
if numel(xy)~=2 || any(~isfinite(xy)) || xy(1)<env.xLim(1) || xy(1)>env.xLim(2) || ...
        xy(2)<env.yLim(1) || xy(2)>env.yLim(2)
    error('load_dem_environment:PointOutside','%s must lie inside the DEM extent.',name);
end
end

function text=read_crs_text(info)
text='unknown';
if isempty(info), return; end
try
    crs=info.CoordinateReferenceSystem;
    if isempty(crs), return; end
    try
        text=char(crs.Name);
    catch
        text=char(string(crs));
    end
catch
end
end
