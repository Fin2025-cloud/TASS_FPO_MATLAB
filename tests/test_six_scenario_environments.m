function test_six_scenario_environments()
%TEST_SIX_SCENARIO_ENVIRONMENTS 验证六环境均可构建且真实/合成标志正确。
cfg=default_config();
for sid=1:6
    env=build_scenario_environment(cfg,sid,100000+sid*1000);
    assert(strcmp(env.id,sprintf('S%d',sid)),'Scenario ID mismatch.');
    assert(all(isfinite(env.start)) && all(isfinite(env.goal)), ...
        'Start/goal must be finite.');
    assert(env.start(1)>=env.xLim(1) && env.start(1)<=env.xLim(2));
    assert(env.start(2)>=env.yLim(1) && env.start(2)<=env.yLim(2));
    assert(env.goal(1)>=env.xLim(1) && env.goal(1)<=env.xLim(2));
    assert(env.goal(2)>=env.yLim(1) && env.goal(2)<=env.yLim(2));
    startTerrain=terrain_height(env,env.start(1),env.start(2));
    goalTerrain=terrain_height(env,env.goal(1),env.goal(2));
    assert(env.start(3)-startTerrain>=cfg.constraint.clearance-1e-10);
    assert(env.goal(3)-goalTerrain>=cfg.constraint.clearance-1e-10);
    if sid<=2
        assert(~env.meta.isRealDEM,'S1/S2 must be synthetic.');
    else
        assert(env.meta.isRealDEM,'S3-S6 must use real DEM data.');
        assert(isfield(env.terrain,'Zraw') && ~isempty(env.terrain.Zraw));
        assert(~isempty(env.terrain.sha256));
        assert(env.terrain.checksumVerified,'DEM checksum was not verified.');
    end
end
end
