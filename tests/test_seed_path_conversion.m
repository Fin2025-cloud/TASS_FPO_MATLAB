function test_seed_path_conversion()
%TEST_SEED_PATH_CONVERSION 回归验证 A* 折线到 K+2 三维控制点的转换。
%
% 该测试专门防止旧版本中的长度不一致赋值：
% z(2:end-1)=movmean(z,3,'Endpoints','shrink')。
% movmean 返回 K+2 个元素，而左侧只有 K 个内部元素，因此会触发
% MATLAB:matrix:singleSubscriptNumelMismatch。本版只写回平滑结果内部区间。

% 创建默认配置。
cfg = default_config();

% 使用 5 个内部控制点，使期望完整控制点数量为 7。
cfg.path.K = 5;

% 用固定种子构建基础合成环境。
env = build_synthetic_environment(cfg, 1, 456);

% 构造一条包含多个二维折点的测试折线。
xyPath = [env.start(1:2); 300, 250; 520, 480; ...
    760, 700; 950, 900; env.goal(1:2)];

% 把二维折线转换为三维 B 样条控制点。
controlPoints = path_to_control_points(xyPath, env, cfg);

% 完整控制点数量必须等于 K+2。
assert(size(controlPoints, 1) == cfg.path.K + 2, ...
    'The converted path must contain K+2 control points.');

% 每个控制点必须包含 x、y、z 三个坐标。
assert(size(controlPoints, 2) == 3, ...
    'Each control point must contain exactly three coordinates.');

% 所有控制点数值必须有限。
assert(all(isfinite(controlPoints(:))), ...
    'Converted control points must be finite.');

% 首控制点必须与固定起点完全一致。
assert(isequaln(controlPoints(1, :), env.start), ...
    'The first control point must equal the fixed start point.');

% 尾控制点必须与固定终点完全一致。
assert(isequaln(controlPoints(end, :), env.goal), ...
    'The last control point must equal the fixed goal point.');
end
