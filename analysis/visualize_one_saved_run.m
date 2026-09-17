function visualize_one_saved_run(matFile)
%VISUALIZE_ONE_SAVED_RUN 快速查看一个已保存的单次实验 MAT 文件。
%
% 示例：
%   matFile = fullfile(pwd,'results','formal_equal_FE', ...
%       'scenario_S1','TAAS-FPO', ...
%       'TAAS-FPO_S1_run001_seed201001.mat');
%   visualize_one_saved_run(matFile);
%
% 本函数只加载 MAT 文件并调用工程中已有的绘图函数，不重新运行算法。

if nargin < 1 || isempty(matFile)
    [fileName,folderName] = uigetfile( ...
        fullfile(pwd,'results','formal_equal_FE','**','*.mat'), ...
        '选择一个单次实验 MAT 文件');

    if isequal(fileName,0)
        fprintf('用户取消选择，未生成图形。\n');
        return;
    end

    matFile = fullfile(folderName,fileName);
end

if ~isfile(matFile)
    error('visualize_one_saved_run:FileNotFound', ...
        'MAT 文件不存在：%s',matFile);
end

loaded = load(matFile,'record','fullData');

if isfield(loaded,'fullData')
    % 兼容旧版实验文件
    data = loaded.fullData;

elseif isfield(loaded,'record') && ...
        isfield(loaded.record,'configuration') && ...
        isfield(loaded.record,'environment') && ...
        isfield(loaded.record,'convergence') && ...
        isfield(loaded.record,'output')

    % 新版 paper 协议记录转换为绘图函数使用的字段名称
    r = loaded.record;
    data = struct();
    data.cfg = r.configuration;
    data.env = r.environment;
    data.curve = r.convergence;
    data.output = r.output;

else
    error('visualize_one_saved_run:UnsupportedRecord', ...
        'MAT 文件既不是旧版 fullData，也不是新版 paper record：%s',matFile);
end
required = {'cfg','env','curve','output'};
for index = 1:numel(required)
    if ~isfield(data,required{index})
        error('visualize_one_saved_run:MissingField', ...
            'fullData 缺少字段 %s。',required{index});
    end
end

if ~isfield(data.output,'bestResult') || isempty(data.output.bestResult)
    error('visualize_one_saved_run:NoBestResult', ...
        '该运行没有可绘制的 bestResult。');
end

result = data.output.bestResult;

figure('Name','Saved run: 3-D path','Color','w');
plot_path_3d(data.env,result,data.cfg);

figure('Name','Saved run: convergence','Color','w');
plot_convergence_fe(data.curve);

if isfield(data.output,'log') && ...
        isfield(data.output.log,'FE') && ...
        ~isempty(data.output.log.FE)

    figure('Name','Saved run: strategy probabilities','Color','w');
    plot_strategy_prob(data.output.log);
end

if isfield(data.output,'repairStats') && ...
        isstruct(data.output.repairStats) && ...
        isfield(data.output.repairStats,'byType') && ...
        ~isempty(fieldnames(data.output.repairStats.byType))

    figure('Name','Saved run: repair statistics','Color','w');
    plot_repair_stats(data.output.repairStats);
end

fprintf('\n已加载：%s\n',matFile);
fprintf('Feasible = %d\n',result.isFeasible);
fprintf('F = %.8g\n',result.F);
fprintf('CV = %.8g\n',result.CV);

if isfield(result,'cost')
    fprintf('Length = %.3f m\n',result.cost.length);
    fprintf('Energy = %.3f J\n',result.cost.energy);
    fprintf('Flight time = %.3f s\n',result.cost.time);
end
end
