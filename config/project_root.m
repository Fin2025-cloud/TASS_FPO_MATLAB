function root = project_root()
%PROJECT_ROOT 返回当前工程根目录，避免各脚本依赖 pwd 或自身所在目录。
%
% 本函数优先定位统一入口 FPO_LAB.m；若入口暂时不在 MATLAB 路径中，
% 则根据本文件位于 <root>/config 的固定结构回退解析。

entryFile = which('FPO_LAB');
if ~isempty(entryFile)
    root = fileparts(entryFile);
else
    root = fileparts(fileparts(mfilename('fullpath')));
end
end
