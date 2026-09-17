function A=paper_report(batchFolder)
%PAPER_REPORT Includes errors/failures in denominator; energy conditional on success.
R=jsondecode(fileread(fullfile(batchFolder,'run_summary.json')));
groups=unique(strcat({R.candidate},'|',{R.variant}));
A=struct([]);
for k=1:numel(groups)
 pair=strsplit(groups{k},'|');ix=strcmp({R.candidate},pair{1})&strcmp({R.variant},pair{2});
 rr=R(ix);ok=[rr.validatedFeasible]&strcmp({rr.status},'complete');
 n=numel(rr);s=sum(ok);ph=s/n;z=1.95996398454005;
 center=(ph+z^2/(2*n))/(1+z^2/n);
 half=z*sqrt(ph*(1-ph)/n+z^2/(4*n^2))/(1+z^2/n);
 e=[rr(ok).energy];q=[rr(ok).F];
 a=struct('candidate',pair{1},'variant',pair{2},'attemptedRuns',n, ...
 'completedRuns',sum(strcmp({rr.status},'complete')),'successfulRuns',s, ...
 'feasibleRate',ph,'Wilson95Low',max(0,center-half),'Wilson95High',min(1,center+half), ...
 'energyMedian',NaN,'energyQ25',NaN,'energyQ75',NaN,'FMedian',NaN, ...
 'energySampleCount',numel(e),'errorRuns',sum(strcmp({rr.status},'error')), ...
 'searchSecondsMedian',NaN);
 if ~isempty(e)
  a.energyMedian=median(e);a.FMedian=median(q);
  qq=paper_percentile(e,[.25,.75]);a.energyQ25=qq(1);a.energyQ75=qq(2);
 end
 ts=[rr.searchSeconds];ts=ts(isfinite(ts));if ~isempty(ts),a.searchSecondsMedian=median(ts);end
 A(end+1)=a;
end
paper_write_json(fullfile(batchFolder,'aggregate.json'),A);
disp(A);
end
