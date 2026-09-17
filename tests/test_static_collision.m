function test_static_collision()
%TEST_STATIC_COLLISION 验证有限圆柱有符号距离和线段穿越不会被漏检。
o=struct('type','cylinder','center',[0,0],'radius',2,'zMin',0,'zMax',10,'name','test');
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
[dInside,~]=point_to_cylinder_distance([0,0,5],o);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
[dOutside,~]=point_to_cylinder_distance([5,0,5],o);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(abs(dInside+2)<1e-10,'Inside penetration depth should be -2.');
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(abs(dOutside-3)<1e-10,'Outside surface distance should be 3.');

% [逐行说明] 计算或更新 `[dmin,tmin]`，供后续算法、评价或日志步骤使用。
[dmin,tmin]=segment_cylinder_min_distance([-5,0,5],[5,0,5],o);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(dmin<0,'Crossing segment must have negative signed distance.');
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(tmin>0&&tmin<1,'Minimum must lie inside the segment.');

% [逐行说明] 计算或更新 `cfg`，供后续算法、评价或日志步骤使用。
cfg=default_config();cfg.uav.radius=0.5;cfg.constraint.staticSafety=0.5;
% [逐行说明] 计算或更新 `env`，供后续算法、评价或日志步骤使用。
env=struct('staticObstacles',o);
% [逐行说明] 计算或更新 `out`，供后续算法、评价或日志步骤使用。
out=static_obstacle_check([-5,0,5;5,0,5],env,cfg);
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(out.maxDeficit>0,'Static collision deficit was not detected.');
% [逐行说明] 验证必须成立的程序或物理不变量。
assert(out.worstObstacle==1&&out.worstSegment==1,'Worst collision index is incorrect.');
end
