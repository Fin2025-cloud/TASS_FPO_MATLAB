function report = smoke_test_environment_library(cfg)
%SMOKE_TEST_ENVIRONMENT_LIBRARY Build all 30 scenes and optional problem interfaces.
if nargin<1||isempty(cfg),cfg=environment_config();end
C=environment_catalog(); passed=false(numel(C),1); message=strings(numel(C),1);
t0=tic;
for k=1:numel(C)
    try
        env=build_environment_candidate(C(k).id,cfg);
        % Construct the evaluator interface but never call an optimizer.
        make_problem(env,cfg);
        passed(k)=true; message(k)="OK";
    catch ME
        message(k)=string(ME.identifier)+": "+string(ME.message);
    end
end
report=table(string({C.id})',passed,message,'VariableNames',{'id','passed','message'});
disp(report); fprintf('Smoke test completed in %.2f s; optimizer calls: 0.\n',toc(t0));
if ~all(passed),error('smoke_test_environment_library:Failure','One or more candidates failed.');end
end
