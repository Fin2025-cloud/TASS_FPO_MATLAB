function m=paper_code_manifest()
%PAPER_CODE_MANIFEST Hash executable MATLAB sources, excluding results and docs.
root=paper_root();
folders={'algorithms','baselines','benchmarks','config','initialization', ...
 'uav_problems','environment_library','algorithm_bridge','experiments','analysis','protocol','tests','data'};
items=struct('path',{},'sha256',{});
for k=1:numel(folders),items=walk(fullfile(root,folders{k}),root,items);end
for name={'FPO_LAB.m','FPO_PAPER.m','startup.m'}
 file=fullfile(root,name{1});
 if isfile(file),items(end+1)=struct('path',name{1},'sha256',paper_hash(file,'file'));end
end
[~,ix]=sort({items.path});items=items(ix);
m=struct('files',items,'sha256',paper_hash(jsonencode(items)));
end
function items=walk(folder,root,items)
if ~isfolder(folder),return;end
d=dir(folder);
for k=1:numel(d)
 if any(strcmp(d(k).name,{'.','..'})),continue;end
 f=fullfile(folder,d(k).name);
 if d(k).isdir,items=walk(f,root,items);
 elseif (numel(d(k).name)>2&&strcmpi(d(k).name(end-1:end),'.m')) || ...
        strncmp(f,fullfile(root,'data'),numel(fullfile(root,'data')))
  rel=strrep(f(numel(root)+2:end),'\','/');
  items(end+1)=struct('path',rel,'sha256',paper_hash(f,'file'));
 end
end
end
