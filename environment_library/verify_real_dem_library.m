function report = verify_real_dem_library()
%VERIFY_REAL_DEM_LIBRARY Verify packaged GeoTIFF/MAT SHA-256 values from manifest.
root=fileparts(fileparts(mfilename('fullpath')));
manifest=jsondecode(fileread(fullfile(root,'data','provenance','real_dem_manifest.json')));
items=manifest.items; n=numel(items); ok=false(n,2); rows=cell(n,5);
for k=1:n
    tif=fullfile(root,'data','dem','geotiff',items(k).processedGeoTIFF);
    mat=fullfile(root,'data','dem','cache',items(k).cacheMAT);
    a=sha256_file(tif); b=sha256_file(mat);
    ok(k,:)=[strcmpi(a,items(k).geoTIFFSHA256),strcmpi(b,items(k).cacheSHA256)];
    rows(k,:)={items(k).terrainKey,items(k).sourceTile,ok(k,1),ok(k,2),items(k).reliefM};
end
report=cell2table(rows,'VariableNames',{'terrainKey','sourceTile','geoTIFF_OK','cache_OK','reliefM'});
disp(report);
if ~all(ok(:)),error('verify_real_dem_library:Checksum','At least one data file failed SHA-256 verification.');end
fprintf('All public DEM files and read-speed caches passed SHA-256 verification.\n');
end
