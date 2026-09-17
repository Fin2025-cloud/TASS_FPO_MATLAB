function paper_write_json(file,data)
%PAPER_WRITE_JSON Atomic writer, replacing only its named protocol file.
parent=fileparts(file);if ~isfolder(parent),mkdir(parent);end
tmp=[tempname(parent),'.json'];
f=fopen(tmp,'w','n','UTF-8');if f<0,error('paper:Write','Cannot write JSON.');end
try
 fprintf(f,'%s',jsonencode(data));fclose(f);
 [ok,msg]=movefile(tmp,file,'f');if ~ok,error('paper:Move','%s',msg);end
catch ME
 if f>0,try,fclose(f);catch,end,end
 rethrow(ME);
end
end
