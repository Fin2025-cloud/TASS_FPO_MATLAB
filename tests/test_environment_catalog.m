function test_environment_catalog()
%TEST_ENVIRONMENT_CATALOG 检查 30 个候选目录的编号、场景和推荐项。
%
% 该测试不构建 DEM、不运行优化器，通常可在瞬间完成。

C = environment_catalog();
assert(numel(C)==30,'Environment catalog must contain 30 candidates.');
ids = string({C.id});
assert(numel(unique(ids))==30,'Candidate IDs must be unique.');

for scenarioId = 1:6
    idx = find([C.scenarioId]==scenarioId);
    assert(numel(idx)==5,'S%d must contain exactly five candidates.',scenarioId);
    variants = string(arrayfun(@(c)char(c),'A':'E','UniformOutput',false));
    expected = compose("S%d-%s",scenarioId,variants);
    actual = sort(ids(idx));
    assert(isequal(actual(:),sort(expected(:))), ...
        'S%d candidate IDs are incomplete or malformed.',scenarioId);
    assert(sum([C(idx).recommended])==1, ...
        'S%d must have exactly one recommended default candidate.',scenarioId);
end

realItems = C(strcmpi({C.terrainType},'real'));
assert(numel(realItems)==20,'S3-S6 should contain 20 real-terrain candidates.');
R = real_dem_catalog();
validKeys = string({R.key});
assert(all(ismember(string({realItems.terrainKey}),validKeys)), ...
    'At least one real candidate refers to an unknown DEM key.');

fprintf('test_environment_catalog passed.\n');
end
