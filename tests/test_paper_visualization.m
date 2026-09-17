function report = test_paper_visualization()
%TEST_PAPER_VISUALIZATION Synthetic schema test; never reads formal results.
root=tempname;mkdir(root);cleanup=onCleanup(@()remove_temp(root)); %#ok<NASGU>
rows=repmat(template_row(),1,4);
rows(1)=make_row('S1-B','TAAS-FPO',1,true,100,1.1,2.0);
rows(2)=make_row('S1-B','TAAS-FPO',2,false,NaN,NaN,2.2);
rows(3)=make_row('S1-B','PSO',1,true,115,1.4,1.8);
rows(4)=make_row('S1-B','PSO',2,false,NaN,NaN,1.9);
paper_write_json(fullfile(root,'run_summary.json'),rows);
out=fullfile(root,'derived_figures');
opts=struct('figureVisible','off','exportFIG',false, ...
    'makeRepresentativeComparisons',false,'outputDir',out);
result=visualize_paper_results(root,opts);
assert(isfile(fullfile(out,'aggregate.json')),'Missing aggregate.json.');
assert(isfile(fullfile(out,'representative_runs.csv')),'Missing representative_runs.csv.');
assert(isfile(fullfile(out,'visualization_report.mat')),'Missing visualization_report.mat.');
png=dir(fullfile(out,'summary_*.png'));
assert(~isempty(png),'No summary figure was exported.');
assert(isfile(fullfile(root,'run_summary.json')),'Input summary was removed.');
report=struct('passed',true,'derivedFileCount',numel(dir(fullfile(out,'*')))-2, ...
    'outputDir',out,'visualizationReport',result);
fprintf('PASS test_paper_visualization: source summary preserved; derived outputs isolated.\n');
end

function row=template_row()
row=struct('runId','','candidate','','variant','','seedId',1,'status','complete', ...
    'validatedFeasible',false,'validationCV',1,'energy',NaN,'F',NaN, ...
    'searchSeconds',NaN,'recordSHA256','');
end

function row=make_row(candidate,variant,seed,feasible,energy,F,seconds)
row=template_row();row.candidate=candidate;row.variant=variant;row.seedId=seed;
row.runId=sprintf('%s_%s_seed%03d',candidate,variant,seed);
row.validatedFeasible=feasible;row.energy=energy;row.F=F;
row.searchSeconds=seconds;if feasible,row.validationCV=0;end
end

function remove_temp(folder)
if isfolder(folder),rmdir(folder,'s');end
end
