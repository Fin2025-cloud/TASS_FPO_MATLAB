function env = load_real_candidate(item,cfg)
%LOAD_REAL_CANDIDATE 从逐像元一致 MAT 缓存快速读取公开真实 DSM。
%
% MAT 缓存只用于缩短重复读取时间。正式预检由 verify_real_dem_library 对
% GeoTIFF 和 MAT 分别进行 SHA-256 核验。缓存中 Z 不平滑、不归一化、不做
% 垂直缩放；x/y 为局部米制坐标，Z 行方向已与递增 y 对齐。

persistent terrainCache verifiedCache
if isempty(terrainCache), terrainCache=containers.Map('KeyType','char','ValueType','any'); end
if isempty(verifiedCache), verifiedCache=containers.Map('KeyType','char','ValueType','logical'); end
key=upper(item.terrainKey);

catalog=real_dem_catalog();
idx=find(strcmpi({catalog.key},key),1);
if isempty(idx), error('load_real_candidate:Key','Unknown real terrain key %s.',key); end
catalogItem=catalog(idx);
root=fileparts(fileparts(mfilename('fullpath')));
cacheFile=fullfile(root,'data','dem','cache',catalogItem.cacheFile);
tifFile=fullfile(root,'data','dem','geotiff',catalogItem.geoTIFFFile);
if ~isfile(cacheFile), error('load_real_candidate:MissingCache','Missing %s.',cacheFile); end
if ~isfile(tifFile), error('load_real_candidate:MissingGeoTIFF','Missing %s.',tifFile); end

verifyRequested = safe_nested(cfg,{'environment','verifyGeoTIFFChecksum'},false) || ...
    safe_nested(cfg,{'data','verifyChecksum'},false);
if verifyRequested
    cacheHash=sha256_file(cacheFile);
    tifHash=sha256_file(tifFile);
    if ~strcmpi(cacheHash,catalogItem.cacheSHA256) || ...
            ~strcmpi(tifHash,catalogItem.geoTIFFSHA256)
        error('load_real_candidate:Checksum', ...
            'SHA-256 verification failed for real terrain %s.',key);
    end
    verifiedCache(key)=true;
end

if isKey(terrainCache,key)
    terrain=terrainCache(key);
else
    d=load(cacheFile,'x','y','Z');
    if ~all(isfield(d,{'x','y','Z'}))
        error('load_real_candidate:CacheFields','Cache %s lacks x/y/Z.',cacheFile);
    end
    x=double(d.x(:)'); y=double(d.y(:)'); Z=double(d.Z);
    if size(Z,1)~=numel(y)||size(Z,2)~=numel(x)||any(diff(x)<=0)||any(diff(y)<=0)
        error('load_real_candidate:CacheGrid','Invalid grid in %s.',cacheFile);
    end
    if any(~isfinite(Z(:)))
        error('load_real_candidate:Nonfinite','Cache contains NaN/Inf: %s.',cacheFile);
    end
    terrain=struct('x',x,'y',y,'Z',Z, ...
        'source','Copernicus DEM GLO-30 Public', ...
        'description',catalogItem.description, ...
        'dataModel','DSM','terrainKey',key,'catalog',catalogItem, ...
        'cacheFile',cacheFile,'geoTIFFFile',tifFile, ...
        'sha256',catalogItem.geoTIFFSHA256, ...
        'cacheSHA256',catalogItem.cacheSHA256, ...
        'crs',catalogItem.crs,'resolution',catalogItem.resolutionM, ...
        'missingFraction',0, ...
        'processing','Fixed crop/reprojection; no smoothing, normalization or vertical scaling.');
    terrainCache(key)=terrain;
end

env=struct();
env.terrain=terrain;
env.xLim=[terrain.x(1),terrain.x(end)];
env.yLim=[terrain.y(1),terrain.y(end)];
minZ=min(terrain.Z(:)); maxZ=max(terrain.Z(:));
env.zLim=[minZ,maxZ+item.zTopMargin];
startXY=fractional_xy(env,item.startFraction);
goalXY=fractional_xy(env,item.goalFraction);
startH=interp2(terrain.x,terrain.y,terrain.Z,startXY(1),startXY(2),'linear');
goalH=interp2(terrain.x,terrain.y,terrain.Z,goalXY(1),goalXY(2),'linear');
env.start=[startXY,startH+cfg.constraint.clearance+item.altitudeMargin];
env.goal=[goalXY,goalH+cfg.constraint.clearance+item.altitudeMargin];
env.staticObstacles=struct([]); env.dynamicObstacles=struct([]);
env.wind=struct('type','constant','constant',[0 0 0]);
env.meta=struct('terrainSource','public_real_DSM','terrainKey',key, ...
    'sourceTile',terrain.catalog.sourceTile,'crs',terrain.catalog.crs, ...
    'resolutionM',terrain.catalog.resolutionM,'terrainModification','none', ...
    'isRealDEM',true,'checksumVerified',verifyRequested);
end
function xy=fractional_xy(env,f)
xy=[env.xLim(1)+f(1)*diff(env.xLim),env.yLim(1)+f(2)*diff(env.yLim)];
end
function value=safe_nested(s,path,defaultValue)
value=defaultValue;
for k=1:numel(path)
    if ~isstruct(s)||~isfield(s,path{k}),return;end
    s=s.(path{k});
end
value=s;
end
