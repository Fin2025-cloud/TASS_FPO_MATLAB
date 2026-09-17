function report = verify_packaged_dem_integrity()
%VERIFY_PACKAGED_DEM_INTEGRITY Verify processed DEMs and source audit crops.
%
% Two artifacts are checked for each independent real-data region:
%   processed   - metre-based 30 m UTM GeoTIFF used by the optimizer;
%   source_crop - exact source-grid pixels before reprojection, included only
%                 for provenance and not used by the optimizer.
%
% The complete 33-37 MB source-tile hashes are recorded in dem_catalog and the
% JSON manifest but cannot be recomputed unless those complete tiles are
% downloaded separately.

startup();
scenarioIds=[3 4 5];
scenarioNames=["S3";"S4";"S5/S6"];
numRegions=numel(scenarioIds);
numArtifacts=2*numRegions;

scenario=strings(numArtifacts,1);
artifactType=strings(numArtifacts,1);
file=strings(numArtifacts,1);
expected=strings(numArtifacts,1);
actual=strings(numArtifacts,1);
matched=false(numArtifacts,1);

modelDir=fileparts(which('dem_catalog'));
projectRoot=fileparts(fileparts(modelDir));
row=0;
for index=1:numRegions
    item=dem_catalog(scenarioIds(index));

    row=row+1;
    scenario(row)=scenarioNames(index);
    artifactType(row)="processed_UTM";
    file(row)=string(fullfile(projectRoot,item.relativeFile));
    expected(row)=string(item.expectedSHA256);
    actual(row)=string(sha256_file(char(file(row))));
    matched(row)=strcmpi(expected(row),actual(row));

    row=row+1;
    scenario(row)=scenarioNames(index);
    artifactType(row)="source_audit_crop";
    file(row)=string(fullfile(projectRoot,item.sourceAuditFile));
    expected(row)=string(item.sourceAuditSHA256);
    actual(row)=string(sha256_file(char(file(row))));
    matched(row)=strcmpi(expected(row),actual(row));
end

report=table(scenario,artifactType,file,expected,actual,matched, ...
    'VariableNames',{'Scenario','ArtifactType','File','ExpectedSHA256', ...
    'ActualSHA256','Matched'});
disp(report);
if ~all(matched)
    error('verify_packaged_dem_integrity:Mismatch', ...
        'At least one packaged DEM artifact checksum does not match.');
end
end
