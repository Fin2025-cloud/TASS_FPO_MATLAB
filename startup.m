function rootDir = startup(forceBanner)
%STARTUP 加载 TAAS-FPO v1.3.1 精简正式实验版。
%
%   startup
%   rootDir = startup
%
% 只修改当前 MATLAB 会话的搜索路径，不写入永久 path，不运行算法。
% 正常使用只需运行 FPO_LAB；保留 startup 是为了兼容内部函数和命令行调用。

if nargin < 1, forceBanner = false; end
rootDir = fileparts(mfilename('fullpath'));

% 只加入实际运行所需目录。docs/archive 不加入路径，避免旧入口与新入口冲突。
folders = {'algorithms','baselines','benchmarks','config','initialization', ...
    'uav_problems','environment_library','algorithm_bridge','experiments', ...
    'analysis','tests','protocol'};
addpath(rootDir);
for i = 1:numel(folders)
    folder = fullfile(rootDir,folders{i});
    if isfolder(folder), addpath(genpath(folder)); end
end

persistent bannerShown
if forceBanner || isempty(bannerShown)
    fprintf('TAAS-FPO MATLAB v2.0.0 Evidence Protocol is ready.\n');
    fprintf('Unified entry: FPO_LAB\n');
    fprintf('Project root : %s\n',rootDir);
    bannerShown = true;
end
end
