function env = strip_runtime_cache(env)
%STRIP_RUNTIME_CACHE 删除可重建缓存后再保存环境。
%
% griddedInterpolant 和基函数矩阵可由 DEM、K、M 与样条次数确定性重建。
% 保存每次运行时删除这些对象，可以显著减小 MAT 文件并避免并行工作进程
% 的内部对象进入长期结果档案；原始地形矩阵和全部元数据保持不变。

if isfield(env,'cache')
    env = rmfield(env,'cache');
end
end
