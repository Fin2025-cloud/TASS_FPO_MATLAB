function run_release_tests()
%RUN_RELEASE_TESTS 运行 v1.3.1 新增功能的快速测试，不运行完整优化实验。
startup;
test_environment_catalog();
verify_real_dem_library();
test_selected_environment_bridge();
test_environment_selection_freeze();
test_experiment_signature_guard();
fprintf('All v1.3.1 integration tests passed.\n');
end
