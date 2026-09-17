function cfg = formal_experiment_config(profile)
%FORMAL_EXPERIMENT_CONFIG 生成可复现的路径规划实验配置。
%
% profile 可选：
%   'smoke'   - 极小预算，只检查算法与环境接口；不能作为论文数据。
%   'quick'   - 小预算观察路径和约束；不能作为论文数据。
%   'pilot'   - 预实验，用于估计运行时间和可行率；不能替代正式统计。
%   'formal'  - 保留 v1.1.1 的正式 N、MaxFEs、路径采样和 30 次独立运行。
%
% 本函数不会运行算法。正式实验默认读取环境工作室“选项5”保存的环境组合，
% 也可以将 cfg.environment.mode 改成 'featured_v111'，复现 v1.1.1 冻结场景。

if nargin < 1 || isempty(profile)
    profile = 'formal';
end
profile = lower(strtrim(char(profile)));

% 始终从 v1.1.1 完整配置开始，避免环境筛选配置中的小预算参数泄漏到正式实验。
cfg = default_config();

% 环境库运行参数。preview* 只影响绘图，绝不进入路径评价。
cfg.environment.mode = 'selected_library';
cfg.environment.selectionFile = fullfile('data','selections','selected_environments.mat');
cfg.environment.candidateIds = {};
cfg.environment.syntheticMapSize = [1800,1500];
cfg.environment.syntheticGridSize = [181,151];
cfg.environment.previewMaxGrid = 105;
cfg.environment.previewWindGrid = [4,3];
cfg.environment.showGuideRoutes = false;
cfg.environment.realCachePreferred = true;
cfg.environment.verifyGeoTIFFChecksum = true;

% 运行管理。resume=true 会跳过已经完整保存且元数据一致的运行。
cfg.experiment.profile = profile;
cfg.experiment.resume = true;
cfg.experiment.resumeErrorRuns = false;
cfg.experiment.overwriteExisting = false;
cfg.experiment.checkpointAfterScenario = true;
cfg.experiment.baseAlgorithmSeed = 200000;
% 所有比较算法必须消耗恰好 MaxFEs 次完整评价；否则该次运行标记为错误。
cfg.experiment.requireExactFEs = true;
cfg.experiment.release = '1.3.1';
cfg.experiment.environmentMode = cfg.environment.mode;
cfg.experiment.assertFormalBudget = strcmp(profile,'formal');

switch profile
    case 'smoke'
        cfg.path.K = 6;
        cfg.path.M = 60;
        cfg.path.enableAdaptiveSampling = false;
        cfg.path.maxAdaptivePoints = 60;
        cfg.path.maxRefineRounds = 0;
        cfg.algorithm.N = 6;
        cfg.algorithm.MaxFEs = 120;
        cfg.algorithm.logEveryFE = 10;
        cfg.algorithm.assertInvariants = false;
        cfg.algorithm.verbose = false;
        cfg.initialization.numSeedPaths = 2;
        cfg.initialization.gridSize = [21,21];
        cfg.initialization.maxAstarExpansions = 1e4;
        cfg.repair.maxRounds = 1;
        cfg.repair.maxInitRounds = 1;
        cfg.experiment.numRuns = 1;

    case 'quick'
        cfg.path.K = 8;
        cfg.path.M = 100;
        cfg.path.enableAdaptiveSampling = false;
        cfg.path.maxAdaptivePoints = 100;
        cfg.path.maxRefineRounds = 0;
        cfg.algorithm.N = 10;
        cfg.algorithm.MaxFEs = 500;
        cfg.algorithm.logEveryFE = 20;
        cfg.algorithm.assertInvariants = false;
        cfg.algorithm.verbose = false;
        cfg.initialization.numSeedPaths = 3;
        cfg.initialization.gridSize = [31,31];
        cfg.initialization.maxAstarExpansions = 4e4;
        cfg.repair.maxRounds = 1;
        cfg.repair.maxInitRounds = 1;
        cfg.experiment.numRuns = 1;

    case 'pilot'
        cfg.path.K = 10;
        cfg.path.M = 220;
        cfg.path.enableAdaptiveSampling = true;
        cfg.path.maxAdaptivePoints = 380;
        cfg.path.maxRefineRounds = 2;
        cfg.algorithm.N = 25;
        cfg.algorithm.MaxFEs = 5000;
        cfg.algorithm.logEveryFE = 50;
        cfg.algorithm.assertInvariants = false;
        cfg.algorithm.verbose = false;
        cfg.initialization.numSeedPaths = 5;
        cfg.initialization.gridSize = [45,45];
        cfg.initialization.maxAstarExpansions = 1e5;
        cfg.experiment.numRuns = 3;

    case 'formal'
        % 不修改 v1.1.1 的科学参数：K=12、M=400、N=60、MaxFEs=50000、30 runs。
        % 关闭仅用于开发检查的断言和逐步输出，不改变候选解、目标函数或约束。
        cfg.algorithm.assertInvariants = false;
        cfg.algorithm.verbose = false;

    otherwise
        error('formal_experiment_config:Profile', ...
            'Unknown profile "%s". Use smoke, quick, pilot or formal.',profile);
end

% 每个 profile 使用独立目录，防止小预算结果与正式结果混合。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.experiment.outputDir = fullfile(projectRoot,'results', ...
    sprintf('%s_selected_v131',profile));

validate_config(cfg);
end
