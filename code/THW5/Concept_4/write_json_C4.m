function write_json_C4(filename,value)
try
    content = jsonencode(value,'PrettyPrint',true);
catch
    content = jsonencode(value);
end
[fid,msg] = fopen(filename,'w','n','UTF-8');
if fid < 0, error('C4:File','Cannot open %s: %s',filename,msg); end
clean = onCleanup(@() fclose(fid));
fprintf(fid,'%s',content);
end
