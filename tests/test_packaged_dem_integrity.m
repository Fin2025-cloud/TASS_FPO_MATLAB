function test_packaged_dem_integrity()
%TEST_PACKAGED_DEM_INTEGRITY Check processed and source-audit GeoTIFF hashes.
scenarioIds=[3 4 5];
modelDir=fileparts(which('dem_catalog'));
projectRoot=fileparts(fileparts(modelDir));
for scenarioId=scenarioIds
    item=dem_catalog(scenarioId);

    processedFile=fullfile(projectRoot,item.relativeFile);
    assert(isfile(processedFile),'Missing packaged DEM: %s',processedFile);
    processedHash=sha256_file(processedFile);
    assert(strcmpi(processedHash,item.expectedSHA256), ...
        'Processed DEM SHA-256 mismatch for scenario %d.',scenarioId);

    auditFile=fullfile(projectRoot,item.sourceAuditFile);
    assert(isfile(auditFile),'Missing source audit crop: %s',auditFile);
    auditHash=sha256_file(auditFile);
    assert(strcmpi(auditHash,item.sourceAuditSHA256), ...
        'Source audit crop SHA-256 mismatch for scenario %d.',scenarioId);
end
end
