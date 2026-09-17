function paper_export_summary(folder,R)
%PAPER_EXPORT_SUMMARY Plain UTF-8 CSV, null/NaN metrics blank, no imputation.
fields={'runId','candidate','variant','seedId','profile','partition','status', ...
 'searchFeasible','validatedFeasible','actualFEs','firstSearchFeasibleFE', ...
 'energy','F','length','flightTime','searchSeconds','validationSeconds','errorId'};
f=fopen(fullfile(folder,'run_summary.csv'),'w','n','UTF-8');
if f<0,error('paper:Write','Cannot write CSV.');end
c=onCleanup(@()fclose(f));fprintf(f,'%s\n',strjoin(fields,','));
for k=1:numel(R)
 values=cell(1,numel(fields));
 for j=1:numel(fields)
  a=R(k).(fields{j});
  if isempty(a),values{j}='';
  elseif isnumeric(a)||islogical(a)
   if isfinite(a),values{j}=sprintf('%.15g',a);else,values{j}='';end
  else,values{j}=['"',strrep(char(a),'"','""'),'"'];end
 end
 fprintf(f,'%s\n',strjoin(values,','));
end
end

