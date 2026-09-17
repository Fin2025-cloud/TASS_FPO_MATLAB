function test_s3_featured_real_dem()
%TEST_S3_FEATURED_REAL_DEM 确认新版 S3 使用高特征真实 DSM 和收紧高度余量。
cfg = default_config();
env = build_scenario_environment(cfg,3,103000);
assert(env.meta.isRealDEM);
assert(contains(string(env.meta.catalog.sourceTile),'N38_00_W080_00'));
relief = max(env.terrain.Z(:))-min(env.terrain.Z(:));
assert(relief>500,'S3 local relief should exceed 500 m in v1.1.1.');
assert(abs(env.zLim(2)-max(env.terrain.Z(:))-80)<1e-8, ...
    'S3 z ceiling must equal terrain maximum plus the frozen 80 m margin.');
assert(norm(env.goal(1:2)-env.start(1:2))>0.8*diff(env.xLim), ...
    'S3 start and goal must span most of the DSM width.');
end
