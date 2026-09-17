function varargout = FPO_LAB(action,varargin)
%FPO_LAB TAAS-FPO v2.0.0 主控；论文协议入口为 FPO_PAPER。
%
% 交互使用：
%   FPO_LAB
%
% 命令调用：
%   FPO_LAB('environment')   环境查看、选择与保存
%   FPO_LAB('quick')         低预算多算法对比
%   FPO_LAB('preflight')     正式实验预检，不运行优化器
%   FPO_LAB('pilot')         3 次、5000 FE 预实验
%   FPO_LAB('formal')        30 次、50000 FE 正式实验
%   FPO_LAB('results')       结果绘图与诊断
%   FPO_LAB('verify')        DEM、测试与环境完整性检查
%   FPO_LAB('setup')         仅加载路径
%
% 设计原则：用户只需要记住本文件。算法、评价器和环境函数继续按模块存放，
% 以便单元测试和论文复现；旧 main_* 已移到 docs/archive，不加入运行路径。

entryRoot = fileparts(mfilename('fullpath'));
addpath(entryRoot,'-begin');
startup();
if nargin < 1 || isempty(action), action = 'menu'; end
action = lower(strtrim(char(action)));

switch action
    case 'menu'
        main_menu();
    case {'environment','env'}
        environment_menu();
    case 'quick'
        out = quick_menu(varargin{:});
        if nargout > 0, varargout{1} = out; end
    case 'preflight'
        out = FPO_PAPER('preflight',varargin{:});
        if nargout > 0, varargout{1} = out; end
    case 'pilot'
        out = FPO_PAPER('pilot',varargin{:});
        if nargout > 0, varargout{1} = out; end
    case 'formal'
        out = FPO_PAPER('formal',varargin{:});
        if nargout > 0, varargout{1} = out; end
    case 'paper'
        out=FPO_PAPER(varargin{:});
        if nargout>0,varargout{1}=out;end
    case 'results'
        out = results_menu();
        if nargout > 0, varargout{1} = out; end
    case {'verify','check','tests'}
        verification_menu();
    case 'setup'
        if nargout > 0, varargout{1} = project_root(); end
    case 'help'
        help FPO_LAB;
    otherwise
        error('FPO_LAB:UnknownAction','未知操作：%s',action);
end
end

function main_menu()
while true
    fprintf('\n============================================================\n');
    fprintf(' TAAS-FPO v2.0.0 Evidence Protocol\n');
    fprintf(' 1  环境管理：查看、比较、选择和保存 S1-S6\n');
    fprintf(' 2  快速对比：低预算多场景、多算法与可视化\n');
    fprintf(' 3  正式实验：预检、pilot、正式运行和恢复\n');
    fprintf(' 4  结果与检查：绘图、诊断、DEM 和单元测试\n');
    fprintf(' 5  新论文实验协议与代码测试\n');
    fprintf(' 0  退出\n');
    fprintf('============================================================\n');
    choice = input('请选择：');
    switch choice
        case 1, environment_menu();
        case 2, quick_menu();
        case 3, formal_menu();
        case 4, results_and_checks_menu();
        case 5, FPO_PAPER('help');
        case 0, return;
        otherwise, fprintf('无效选项。\n');
    end
end
end

function environment_menu()
cfg = environment_config();
while true
    fprintf('\n--- 环境管理 ---\n');
    fprintf('1  查看 30 个候选环境指标表\n');
    fprintf('2  查看某类场景的 5 个候选\n');
    fprintf('3  查看一个候选环境\n');
    fprintf('4  查看当前已保存的六个环境\n');
    fprintf('5  修改并保存六个环境\n');
    fprintf('6  查看或保存推荐组合\n');
    fprintf('7  快速验证全部候选与真实 DEM\n');
    fprintf('0  返回\n');
    choice = input('请选择：');
    switch choice
        case 1
            screen_environment_library(cfg,true);
        case 2
            sid = input('场景编号 1-6：');
            visualize_scenario_candidates(sid,cfg);
        case 3
            id = strtrim(input('候选编号，例如 S3-A：','s'));
            visualize_environment_candidate(id,cfg);
        case 4
            try
                ids = load_environment_selection(cfg);
                compare_selected_environments(ids,cfg);
                disp(reshape(string(ids),[],1));
            catch ME
                warning('%s',ME.message);
            end
        case 5
            ids = cell(1,6);
            for sid = 1:6
                ids{sid} = strtrim(input(sprintf('S%d 候选编号：',sid),'s'));
            end
            compare_selected_environments(ids,cfg);
            if ask_yes_no('确认保存这组六个环境？',false)
                save_environment_selection(ids,cfg);
            end
        case 6
            ids = default_environment_selection();
            compare_selected_environments(ids,cfg);
            if ask_yes_no('保存推荐组合作为当前选择？',false)
                save_environment_selection(ids,cfg);
            end
        case 7
            smoke_test_environment_library(cfg);
            verify_real_dem_library();
        case 0
            return;
        otherwise
            fprintf('无效选项。\n');
    end
end
end

function out = quick_menu(varargin)
if nargin >= 1 && isstruct(varargin{1})
    opts = varargin{1};
else
    scenarioText = strtrim(input('场景编号 [2 3]：','s'));
    if isempty(scenarioText), scenarios = [2 3]; else, scenarios = str2num(scenarioText); end %#ok<ST2NM>
    if isempty(scenarios) || any(~ismember(scenarios,1:6))
        error('场景编号必须来自 1~6。');
    end

    algorithmText = strtrim(input( ...
        '算法 [TAAS-FPO,ASA-FPO,PSO]：','s'));
    if isempty(algorithmText)
        algorithms = {'TAAS-FPO','ASA-FPO','PSO'};
    else
        algorithms = strtrim(strsplit(algorithmText,','));
    end

    profile = strtrim(input('预算 smoke/quick/balanced [quick]：','s'));
    if isempty(profile), profile = 'quick'; end
    runs = input('每种算法运行次数 [1]：');
    if isempty(runs), runs = 1; end

    opts = struct('scenarioNumbers',scenarios, ...
        'algorithmNames',{algorithms},'profile',profile,'numRuns',runs);
end
out = run_quick_comparison(opts);
end

function formal_menu()
while true
    fprintf('\n--- 正式实验 ---\n');
    fprintf('1  正式预检（不运行优化器）\n');
    fprintf('2  pilot：3 次、5000 FE\n');
    fprintf('3  正式：30 次、50000 FE，支持中断恢复\n');
    fprintf('4  复现 v1.1.1 冻结环境\n');
    fprintf('0  返回\n');
    choice = input('请选择：');
    switch choice
        case 1, do_preflight();
        case 2, do_experiment('pilot');
        case 3, do_experiment('formal');
        case 4, do_featured_experiment();
        case 0, return;
        otherwise, fprintf('无效选项。\n');
    end
end
end

function report = do_preflight()
report = FPO_PAPER('preflight');
disp(report);
end

function tableOut = do_experiment(profile)
cfg = paper_config(profile);
fprintf('新论文协议默认串行；环境与算法由 paper_config/paper_variants 冻结。\n');
if strcmpi(profile,'formal')
    fprintf('正式实验受人工核准门控；请先阅读 README 和 study_attestation。\n');
    code = strtrim(input('输入 RUN 确认开始，其他输入取消：','s'));
    if ~strcmp(code,'RUN')
        fprintf('已取消。\n');
        tableOut = table();
        return;
    end
end
tableOut = FPO_PAPER('run',cfg);
end

function tableOut = do_featured_experiment()
error('paper:LegacyFormalDisabled', ...
 '旧冻结环境入口仅留作历史代码。论文实验请显式选择候选ID并使用 FPO_PAPER。');
cfg = formal_experiment_config('formal');
cfg.environment.mode = 'featured_v111';
cfg.experiment.environmentMode = cfg.environment.mode;
cfg.experiment.outputDir = fullfile(project_root(),'results', ...
    'formal_featured_v111_v131');
cfg.experiment.useParallel = ask_yes_no('使用并行？',true);
preflight_formal_experiment(cfg,1:6,default_algorithms());
code = strtrim(input('输入 RUN 确认开始：','s'));
if strcmp(code,'RUN')
    tableOut = run_uav_experiments_selectable(cfg,1:6,default_algorithms());
else
    tableOut = table();
    fprintf('已取消。\n');
end
end

function results_and_checks_menu()
while true
    fprintf('\n--- 结果与检查 ---\n');
    fprintf('1  新版正式结果汇总、路径与收敛图\n');
    fprintf('2  用已保存快速结果重新绘图\n');
    fprintf('3  查看一个保存的 record.mat\n');
    fprintf('4  数据与代码完整性检查\n');
    fprintf('5  新版结果可视化结构测试\n');
    fprintf('0  返回\n');
    choice = input('请选择：');
    switch choice
        case 1, results_menu();
        case 2, replot_quick_comparison_clean();
        case 3, visualize_one_saved_run();
        case 4, verification_menu();
        case 5, disp(test_paper_visualization());
        case 0, return;
        otherwise, fprintf('无效选项。\n');
    end
end
end

function report = results_menu()
try
    defaultDir = resolve_paper_batch([], 'formal');
catch ME
    if ~strcmp(ME.identifier,'paper:NoResultBatch'), rethrow(ME); end
    defaultDir = fullfile(project_root(),'results','paper');
    fprintf('当前工程中尚未自动找到正式结果批次，请手动输入批次目录。\n');
end
resultDir = prompt_path('新版正式结果目录',defaultDir);
report = visualize_paper_results(resultDir);
end

function verification_menu()
while true
    fprintf('\n--- 完整性检查 ---\n');
    fprintf('1  正式实验预检\n');
    fprintf('2  真实 DEM 与缓存核验\n');
    fprintf('3  核心单元测试\n');
    fprintf('4  v1.3.x 环境与签名测试\n');
    fprintf('5  六场景快速链路检查\n');
    fprintf('0  返回\n');
    choice = input('请选择：');
    switch choice
        case 1, do_preflight();
        case 2
            verify_real_dem_library();
            verify_packaged_dem_integrity();
        case 3, disp(run_all_tests());
        case 4, run_release_tests();
        case 5, disp(smoke_test_six_scenarios());
        case 0, return;
        otherwise, fprintf('无效选项。\n');
    end
end
end

function algorithms = default_algorithms()
algorithms = {'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'};
end

function tf = ask_yes_no(message,defaultValue)
if defaultValue, suffix = 'Y/n'; else, suffix = 'y/N'; end
answer = strtrim(input(sprintf('%s [%s]：',message,suffix),'s'));
if isempty(answer)
    tf = defaultValue;
else
    tf = strcmpi(answer,'y') || strcmpi(answer,'yes');
end
end

function value = prompt_path(label,defaultValue)
value = strtrim(input(sprintf('%s [%s]：',label,defaultValue),'s'));
if isempty(value), value = defaultValue; end
end
