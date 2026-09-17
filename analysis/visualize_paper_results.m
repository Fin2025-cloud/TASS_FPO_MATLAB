function report = visualize_paper_results(batchFolder,userOptions)
%VISUALIZE_PAPER_RESULTS Visualize immutable v2 paper-protocol results.
% Reads run_summary.json and per-run record.mat files. Raw experiment files
% are never modified; all derived tables and figures go to a new directory.
if nargin<1, batchFolder=[]; end
if nargin<2 || isempty(userOptions), userOptions=struct(); end
batchFolder=resolve_paper_batch(batchFolder,'formal');
opts=merge_options(default_options(),userOptions);

summaryFile=fullfile(batchFolder,'run_summary.json');
R=jsondecode(fileread(summaryFile));
if isempty(R) || ~isstruct(R)
    error('paper:EmptySummary','run_summary.json 没有结构化运行记录：%s',summaryFile);
end
required={'runId','candidate','variant','seedId','status','validatedFeasible'};
for k=1:numel(required)
    if ~isfield(R,required{k})
        error('paper:SummarySchema','run_summary.json 缺少字段 %s。',required{k});
    end
end

if strlength(string(opts.outputDir))==0
    outputDir=unique_output_folder(batchFolder,'figures_paper');
else
    outputDir=char(opts.outputDir);
    if isfolder(outputDir) || isfile(outputDir)
        error('paper:OutputExists','为防止覆盖，输出路径必须尚不存在：%s',outputDir);
    end
end
mkdir(outputDir);

aggregate=aggregate_summary(R);
paper_write_json(fullfile(outputDir,'aggregate.json'),aggregate);
generated=cell(0,1);
candidates=natural_candidates(unique({R.candidate},'stable'));
representativeRows=cell(0,4);

for ci=1:numel(candidates)
    candidate=candidates{ci};
    group=aggregate(strcmp({aggregate.candidate},candidate));
    if ~isempty(group)
        fig=make_summary_figure(group,candidate,opts);
        generated=[generated;export_figure(fig, ...
            fullfile(outputDir,['summary_' safe_name(candidate)]),opts)]; %#ok<AGROW>
        close_if_needed(fig,opts);
    end

    [seedId,basis]=select_representative_seed(R,candidate);
    if ~isfinite(seedId), continue; end
    if ~opts.makeRepresentativeComparisons
        representativeRows(end+1,:)={candidate,seedId,basis,0}; %#ok<AGROW>
        continue;
    end
    items=load_seed_records(batchFolder,R,candidate,seedId);
    representativeRows(end+1,:)={candidate,seedId,basis,numel(items)}; %#ok<AGROW>
    if isempty(items), continue; end

    fig=make_path_figure(items,candidate,seedId,opts);
    generated=[generated;export_figure(fig, ...
        fullfile(outputDir,sprintf('paths_%s_seed%03d',safe_name(candidate),seedId)),opts)]; %#ok<AGROW>
    close_if_needed(fig,opts);

    fig=make_convergence_figure(items,candidate,seedId,opts);
    generated=[generated;export_figure(fig, ...
        fullfile(outputDir,sprintf('convergence_%s_seed%03d',safe_name(candidate),seedId)),opts)]; %#ok<AGROW>
    close_if_needed(fig,opts);
end

representativeRuns=cell2table(representativeRows,'VariableNames', ...
    {'Candidate','SeedID','SelectionBasis','AvailableVariants'});
writetable(representativeRuns,fullfile(outputDir,'representative_runs.csv'));
report=struct('batchFolder',batchFolder,'summaryFile',summaryFile, ...
    'outputDir',outputDir,'aggregate',aggregate, ...
    'representativeRuns',representativeRuns,'generatedFiles',{generated});
save(fullfile(outputDir,'visualization_report.mat'),'report','-v7');
fprintf('\n新版正式结果可视化完成。\n输入：%s\n输出：%s\n',batchFolder,outputDir);
end

function opts=default_options()
opts=struct('figureVisible','off','resolution',300,'exportPNG',true, ...
    'exportFIG',true,'closeAfterExport',true, ...
    'makeRepresentativeComparisons',true,'outputDir','');
end

function A=aggregate_summary(R)
groups=unique(strcat({R.candidate},'|',{R.variant}));
A=struct([]);
for k=1:numel(groups)
    pair=strsplit(groups{k},'|');
    idx=strcmp({R.candidate},pair{1})&strcmp({R.variant},pair{2});
    rows=R(idx);n=numel(rows);
    complete=strcmp({rows.status},'complete');
    complete=complete(:);
    validated=arrayfun(@(r)logical_scalar(r,'validatedFeasible'),rows);
    validated=validated(:);
    success=complete&validated;
    successes=sum(success);rate=successes/n;z=1.95996398454005;
    center=(rate+z^2/(2*n))/(1+z^2/n);
    half=z*sqrt(rate*(1-rate)/n+z^2/(4*n^2))/(1+z^2/n);
    energy=arrayfun(@(r)numeric_scalar(r,'energy'),rows(success));
    objective=arrayfun(@(r)numeric_scalar(r,'F'),rows(success));
    energy=energy(isfinite(energy));objective=objective(isfinite(objective));
    times=arrayfun(@(r)numeric_scalar(r,'searchSeconds'),rows);
    times=times(isfinite(times));
    item=struct('candidate',pair{1},'variant',pair{2},'attemptedRuns',n, ...
        'completedRuns',sum(complete),'successfulRuns',successes, ...
        'feasibleRate',rate,'Wilson95Low',max(0,center-half), ...
        'Wilson95High',min(1,center+half),'energyMedian',NaN, ...
        'energyQ25',NaN,'energyQ75',NaN,'FMedian',NaN, ...
        'energySampleCount',numel(energy),'errorRuns',sum(strcmp({rows.status},'error')), ...
        'searchSecondsMedian',NaN);
    if ~isempty(energy)
        item.energyMedian=median(energy);
        q=paper_percentile(energy,[.25 .75]);
        item.energyQ25=q(1);item.energyQ75=q(2);
    end
    if ~isempty(objective),item.FMedian=median(objective);end
    if ~isempty(times),item.searchSecondsMedian=median(times);end
    A(end+1)=item; %#ok<AGROW>
end
end

function out=merge_options(base,override)
out=base; names=fieldnames(override);
for k=1:numel(names),out.(names{k})=override.(names{k});end
end

function folder=unique_output_folder(parent,prefix)
tag=datestr(now,'yyyymmdd_HHMMSS');
folder=fullfile(parent,[prefix '_' tag]); suffix=1;
while isfolder(folder) || isfile(folder)
    folder=fullfile(parent,sprintf('%s_%s_%02d',prefix,tag,suffix));
    suffix=suffix+1;
end
end

function ordered=natural_candidates(values)
numbers=inf(size(values));
for k=1:numel(values)
    token=regexp(values{k},'^S(\d+)','tokens','once');
    if ~isempty(token),numbers(k)=str2double(token{1});end
end
[~,idx]=sortrows([numbers(:),(1:numel(values))']);ordered=values(idx);
end

function fig=make_summary_figure(A,candidate,opts)
preferred={'FPO-reference','FPO-N','ASA-FPO','TAAS-FPO','DE','PSO','GWO'};
names={A.variant}; rank=zeros(size(names));
for k=1:numel(names)
    hit=find(strcmp(preferred,names{k}),1);
    if isempty(hit),rank(k)=numel(preferred)+k;else,rank(k)=hit;end
end
[~,idx]=sort(rank);A=A(idx);names={A.variant};x=1:numel(A);
fig=figure('Visible',opts.figureVisible,'Color','w','Position',[80 80 1350 820]);
layout=tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
metrics={ [A.feasibleRate], [A.energyMedian], [A.FMedian], [A.searchSecondsMedian] };
labels={'Validated feasible rate','Conditional energy median / J', ...
    'Conditional objective median','Search time median / s'};
for k=1:4
    ax=nexttile(layout);bar(ax,x,metrics{k},'FaceColor',[0.20 0.48 0.72]);
    set(ax,'XTick',x,'XTickLabel',names,'XTickLabelRotation',25);
    ylabel(ax,labels{k});grid(ax,'on');box(ax,'on');
    if k==1,ylim(ax,[0 1]);end
end
title(layout,sprintf('%s formal results (failed/error runs retained)',candidate), ...
    'Interpreter','none');
end

function [seedId,basis]=select_representative_seed(R,candidate)
seedId=NaN;basis='';
candidateMask=strcmp({R.candidate},candidate);
variantMask=strcmp({R.variant},'TAAS-FPO');
idx=find(candidateMask(:)&variantMask(:));
if isempty(idx),idx=find(candidateMask(:));end
completeMask=strcmp({R(idx).status},'complete');
complete=idx(completeMask(:));
validMask=arrayfun(@(q) logical_scalar(R(q),'validatedFeasible') && ...
    isfinite(numeric_scalar(R(q),'F')),complete);
valid=complete(validMask(:));
if ~isempty(valid)
    values=arrayfun(@(q)numeric_scalar(R(q),'F'),valid);
    target=median(values);[~,j]=min(abs(values-target));chosen=valid(j);
    seedId=numeric_scalar(R(chosen),'seedId');basis='TAAS-FPO validated median-F seed';
    return;
end
if isempty(complete),return;end
cv=arrayfun(@(q)numeric_scalar(R(q),'validationCV'),complete);
finiteCV=isfinite(cv);
if any(finiteCV)
    pool=complete(finiteCV);values=cv(finiteCV);[~,j]=min(values);chosen=pool(j);
    basis='minimum validation-CV fallback';
else
    chosen=complete(1);basis='first complete seed fallback';
end
seedId=numeric_scalar(R(chosen),'seedId');
end

function items=load_seed_records(batchFolder,R,candidate,seedId)
items=struct('variant',{},'record',{},'recordFile',{});
candidateMask=strcmp({R.candidate},candidate);
seedMask=arrayfun(@(r)numeric_scalar(r,'seedId')==seedId,R);
completeMask=strcmp({R.status},'complete');
idx=find(candidateMask(:)&seedMask(:)&completeMask(:));
for k=idx(:)'
    recordFile=fullfile(batchFolder,char(R(k).runId),'record.mat');
    if ~isfile(recordFile)
        warning('paper:RecordMissing','缺少记录：%s',recordFile);continue;
    end
    if isfield(R(k),'recordSHA256') && ~isempty(R(k).recordSHA256) && ...
            ~strcmp(paper_hash(recordFile,'file'),char(R(k).recordSHA256))
        warning('paper:RecordIntegrity','记录哈希不匹配，跳过：%s',recordFile);continue;
    end
    loaded=load(recordFile,'record');
    if ~isfield(loaded,'record') || ~isfield(loaded.record,'environment') || ...
            ~isfield(loaded.record,'convergence') || ~isfield(loaded.record,'output') || ...
            ~isfield(loaded.record.output,'bestResult')
        warning('paper:RecordSchema','记录结构不完整，跳过：%s',recordFile);continue;
    end
    items(end+1)=struct('variant',char(R(k).variant), ... %#ok<AGROW>
        'record',loaded.record,'recordFile',recordFile);
end
end

function fig=make_path_figure(items,candidate,seedId,opts)
env=items(1).record.environment;
fig=figure('Visible',opts.figureVisible,'Color','w','Position',[80 80 1280 850]);
ax=axes(fig);hold(ax,'on');
Z=env.terrain.Z;x=env.terrain.x;y=env.terrain.y;
step=max(1,ceil(max(size(Z))/150));
[X,Y]=meshgrid(x(1:step:end),y(1:step:end));
surf(ax,X,Y,Z(1:step:end,1:step:end),'EdgeColor','none', ...
    'FaceAlpha',0.82,'HandleVisibility','off');colormap(ax,parula);
draw_environment_constraints(ax,env,items);
colors=lines(numel(items));
for k=1:numel(items)
    result=items(k).record.output.bestResult;
    if ~isfield(result,'pathSamples')||isempty(result.pathSamples),continue;end
    P=result.pathSamples;
    plot3(ax,P(:,1),P(:,2),P(:,3),'LineWidth',2,'Color',colors(k,:), ...
        'DisplayName',sprintf('%s | feasible=%d',items(k).variant,result.isFeasible));
end
plot3(ax,env.start(1),env.start(2),env.start(3),'go','MarkerFaceColor','g', ...
    'DisplayName','Start');
plot3(ax,env.goal(1),env.goal(2),env.goal(3),'rs','MarkerFaceColor','r', ...
    'DisplayName','Goal');
xlabel(ax,'X / m');ylabel(ax,'Y / m');zlabel(ax,'Z / m');
title(ax,sprintf('%s, representative seed %03d',candidate,seedId),'Interpreter','none');
grid(ax,'on');box(ax,'on');view(ax,43,31);axis(ax,'tight');
legend(ax,'Location','eastoutside','Interpreter','none');
end

function draw_environment_constraints(ax,env,items)
if isfield(env,'staticObstacles')
    for k=1:numel(env.staticObstacles)
        o=env.staticObstacles(k);
        if ~isfield(o,'radius')||~isfield(o,'center')|| ...
                ~isfield(o,'zMin')||~isfield(o,'zMax'),continue;end
        [xx,yy,zz]=cylinder(o.radius,24);
        zz=o.zMin+(o.zMax-o.zMin)*zz;
        surf(ax,xx+o.center(1),yy+o.center(2),zz,'EdgeColor','none', ...
            'FaceAlpha',0.28,'FaceColor',[0.45 0.20 0.65], ...
            'HandleVisibility','off');
    end
end
if ~isfield(env,'dynamicObstacles'),return;end
tf=0;
for k=1:numel(items)
    result=items(k).record.output.bestResult;
    if isfield(result,'arrivalTime')&&~isempty(result.arrivalTime)
        tf=max(tf,max(result.arrivalTime(:),[],'omitnan'));
    end
end
if ~isfinite(tf)||tf<=0,tf=90;end
for k=1:numel(env.dynamicObstacles)
    o=env.dynamicObstacles(k);
    if ~isfield(o,'p0')||~isfield(o,'velocity'),continue;end
    tt=linspace(0,tf,80)';P=o.p0+tt.*o.velocity;
    inside=P(:,1)>=env.xLim(1)&P(:,1)<=env.xLim(2)& ...
        P(:,2)>=env.yLim(1)&P(:,2)<=env.yLim(2)& ...
        P(:,3)>=env.zLim(1)&P(:,3)<=env.zLim(2);
    P=P(inside,:);
    if size(P,1)>=2
        plot3(ax,P(:,1),P(:,2),P(:,3),'--','Color',[0.85 0.33 0.10], ...
            'LineWidth',1.1,'HandleVisibility','off');
    end
end
end

function fig=make_convergence_figure(items,candidate,seedId,opts)
fig=figure('Visible',opts.figureVisible,'Color','w','Position',[80 80 1200 820]);
layout=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
ax1=nexttile(layout);hold(ax1,'on');grid(ax1,'on');
ax2=nexttile(layout);hold(ax2,'on');grid(ax2,'on');
for k=1:numel(items)
    curve=items(k).record.convergence;
    if ~isfield(curve,'FE')||isempty(curve.FE),continue;end
    if isfield(curve,'bestF'),plot(ax1,curve.FE,curve.bestF,'LineWidth',1.5, ...
            'DisplayName',items(k).variant);end
    if isfield(curve,'bestCV'),semilogy(ax2,curve.FE,max(curve.bestCV,eps), ...
            'LineWidth',1.5,'DisplayName',items(k).variant);end
end
xlabel(ax1,'Function evaluations');ylabel(ax1,'Best F');
xlabel(ax2,'Function evaluations');ylabel(ax2,'Best CV');
legend(ax1,'Location','eastoutside','Interpreter','none');
legend(ax2,'Location','eastoutside','Interpreter','none');
title(layout,sprintf('%s, representative seed %03d convergence',candidate,seedId), ...
    'Interpreter','none');
end

function files=export_figure(fig,baseName,opts)
files=cell(0,1);
if opts.exportPNG
    file=[baseName '.png'];exportgraphics(fig,file,'Resolution',opts.resolution);
    files{end+1,1}=file;
end
if opts.exportFIG
    file=[baseName '.fig'];savefig(fig,file);files{end+1,1}=file;
end
end

function close_if_needed(fig,opts)
if opts.closeAfterExport && isgraphics(fig),close(fig);end
end

function value=numeric_scalar(s,name)
value=NaN;
if isfield(s,name)&&isnumeric(s.(name))&&isscalar(s.(name))&&isfinite(s.(name))
    value=double(s.(name));
end
end

function value=logical_scalar(s,name)
value=false;
if isfield(s,name)&&~isempty(s.(name))
    raw=s.(name);value=logical(raw(1));
end
end

function name=safe_name(value)
name=regexprep(char(value),'[^a-zA-Z0-9_-]','_');
end
