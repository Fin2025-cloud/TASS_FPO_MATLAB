function rootDir = startup(forceBanner)
%STARTUP 加载 TAAS-FPO v2.0.0 论文实验工程。
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
addpath(rootDir,'-begin');
for i = 1:numel(folders)
    folder = fullfile(rootDir,folders{i});
    if isfolder(folder), addpath(genpath(folder),'-begin'); end
end

% 多份工程并存时，确保本次显式调用的工程位于搜索路径最前面，并提示重复项。
expectedLab = fullfile(rootDir,'FPO_LAB.m');
activeLab = which('FPO_LAB');
if ~isempty(activeLab) && ~strcmpi(normalize_path(activeLab),normalize_path(expectedLab))
    warning('TAAS:PathConflict', ...
        'MATLAB 路径中存在其他 FPO_LAB：%s；当前工程为：%s',activeLab,expectedLab);
end
allLabs = which('FPO_LAB','-all');
if ischar(allLabs), allLabs = cellstr(allLabs); end
normalizedExpected = normalize_path(expectedLab);
otherLabs = allLabs(~cellfun(@(p)strcmpi(normalize_path(p),normalizedExpected),allLabs));
if ~isempty(otherLabs)
    warning('TAAS:DuplicateProjects', ...
        'MATLAB 路径中还有其他 FPO_LAB；为避免串用，请执行 which FPO_LAB -all 检查。');
end

persistent bannerShown
if forceBanner || isempty(bannerShown)
    fprintf('TAAS-FPO MATLAB v2.0.0 Evidence Protocol is ready.\n');
    fprintf('Unified entry: FPO_LAB\n');
    fprintf('Project root : %s\n',rootDir);
    bannerShown = true;
end

function value = normalize_path(value)
value = strrep(char(value),'/',filesep);
while numel(value)>1 && value(end)==filesep, value(end)=[]; end
end
end
