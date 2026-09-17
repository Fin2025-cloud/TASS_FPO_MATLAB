function report = run_all_tests()
%RUN_ALL_TESTS 执行 TAAS-FPO 独立项目的核心回归测试。
%
% 使用方法
% -------------------------------------------------------------------------
%   startup;
%   report = run_all_tests;
%
% 设计原则
% -------------------------------------------------------------------------
% 1) 所有测试均使用固定随机种子或无随机输入；
% 2) 测试失败不会被吞掉，最终仍抛出总失败异常；
% 3) 每个失败项打印完整调用栈中的文件和行号，便于直接定位；
% 4) 单元测试只验证代码逻辑，不替代正式 30 次独立实验；
% 5) 本函数不修改算法参数文件、场景数据或历史结果。

% 重新调用项目启动脚本，确保测试可以从任意当前目录执行。
startup();

% 按固定顺序登记所有不依赖外部数据的核心测试函数句柄。
tests = {@test_config_validation, @test_deb_rule, @test_bspline, ...
    @test_static_collision, @test_seed_path_conversion, ...
    @test_objective_normalization_resolution, @test_energy_direction, ...
    @test_dynamic_collision, @test_reproducibility_small, ...
    @test_packaged_dem_integrity, @test_six_scenario_environments, ...
    @test_s2_multichannel_topology, @test_s3_featured_real_dem, ...
    @test_fast_cache_equivalence};

% 把每个测试函数句柄转换为可读名称。
testNames = cellfun(@func2str, tests, 'UniformOutput', false);

% 预分配测试是否通过的逻辑列向量。
passed = false(numel(tests), 1);

% 预分配每个测试的结果消息字符串。
message = strings(numel(tests), 1);

% 预分配每个测试的运行时间。
runtime = zeros(numel(tests), 1);

% 逐项运行测试，确保一个测试失败不会阻止其他测试执行。
for i = 1:numel(tests)
    % 启动当前测试计时器。
    timerHandle = tic;

    % 捕获当前测试的异常并记录详细信息。
    try
        % 调用第 i 个测试函数。
        tests{i}();

        % 测试无异常返回时标记为通过。
        passed(i) = true;

        % 保存简洁成功消息。
        message(i) = "ok";

        % 在命令窗口打印通过状态。
        fprintf('[PASS] %s\n', testNames{i});
    catch ME
        % 测试抛出异常时标记为失败。
        passed(i) = false;

        % 组合异常标识和异常正文，保存到报告中。
        message(i) = string(ME.identifier) + ": " + string(ME.message);

        % 在命令窗口打印失败摘要。
        fprintf('[FAIL] %s -> %s\n', testNames{i}, message(i));

        % 打印完整调用栈，修复时不再只能看到顶层错误类型。
        print_exception_stack(ME);
    end

    % 保存当前测试的实际运行时间。
    runtime(i) = toc(timerHandle);
end

% 把测试名称、通过状态、消息和耗时整理为 MATLAB table。
report = table(string(testNames(:)), passed, message, runtime, ...
    'VariableNames', {'Test', 'Passed', 'Message', 'Runtime'});

% 若任意测试失败，则在全部测试结束后抛出汇总异常。
if ~all(passed)
    % 汇总异常确保正式实验脚本不能误把失败测试当作正常完成。
    error('run_all_tests:Failed', '%d/%d tests failed.', ...
        sum(~passed), numel(tests));
end
end

function print_exception_stack(ME)
%PRINT_EXCEPTION_STACK 以兼容格式打印异常调用栈。

% 若异常没有调用栈信息，则无需继续打印。
if isempty(ME.stack)
    % 直接返回调用方。
    return;
end

% 逐层打印发生异常时的函数、文件和行号。
for k = 1:numel(ME.stack)
    % 读取第 k 层调用栈记录。
    stackItem = ME.stack(k);

    % 打印可直接定位的完整文件路径与行号。
    fprintf('       at %s (line %d)\n', stackItem.file, stackItem.line);
end
end
