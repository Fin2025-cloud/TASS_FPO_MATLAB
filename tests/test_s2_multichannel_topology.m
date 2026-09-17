function test_s2_multichannel_topology()
%TEST_S2_MULTICHANNEL_TOPOLOGY 确认 S2 山脊不可越顶且每条屏障有三个山口。
cfg = default_config();
env = build_scenario_environment(cfg,2,102000);
assert(strcmp(env.id,'S2'));
assert(~env.meta.isRealDEM);
assert(~env.meta.ridgeOverflightFeasible, ...
    'S2 ridge tops must be infeasible after adding minimum clearance.');

for xBarrier = env.meta.barrierX
    [~,column] = min(abs(env.terrain.x-xBarrier));
    passable = env.terrain.Z(:,column)+cfg.constraint.clearance <= env.zLim(2);
    numberOfPassages = count_true_runs(passable);
    assert(numberOfPassages==3, ...
        'Each S2 barrier must expose exactly three separated passages.');
end
end

function n = count_true_runs(mask)
mask = logical(mask(:));
transitions = diff([false;mask;false]);
n = nnz(transitions==1);
end
