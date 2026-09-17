function [problem,env,cfg] = make_problem_from_candidate(candidateId,cfg)
%MAKE_PROBLEM_FROM_CANDIDATE Prepare the retained algorithm/evaluator interface.
% This function does not execute an optimizer.
if nargin<2||isempty(cfg),cfg=environment_config();end
env=build_environment_candidate(candidateId,cfg);
problem=make_problem(env,cfg);
end
