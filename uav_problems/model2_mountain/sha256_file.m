function digest = sha256_file(fileName)
%SHA256_FILE 计算文件的 SHA-256，用于核验真实 DEM 未被意外替换。
%
% 输入
% -------------------------------------------------------------------------
% fileName : 待核验文件路径。
%
% 输出
% -------------------------------------------------------------------------
% digest   : 64 位小写十六进制 SHA-256 字符串。
%
% 说明
% -------------------------------------------------------------------------
% 本函数按二进制分块读取文件，不把整个 GeoTIFF 一次性载入内存。正式实验
% 启动时可将结果与 dem_catalog.m 中冻结的摘要比较，从而保证论文所用栅格
% 与发布代码中登记的栅格完全一致。

if ~isfile(fileName)
    error('sha256_file:FileNotFound','File not found: %s',fileName);
end
if exist('OCTAVE_VERSION','builtin')
    digest=paper_hash(fileName,'file');
    return;
end

% Java MessageDigest 在 Windows、Linux 和 macOS 的标准 MATLAB 中均可用。
messageDigest = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(fileName,'rb');
if fid < 0
    error('sha256_file:OpenFailed','Cannot open file: %s',fileName);
end
cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

while ~feof(fid)
    bytes = fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes)
        % Java byte is signed int8; typecast preserves the exact eight bits.
        messageDigest.update(typecast(bytes,'int8'));
    end
end

rawDigest = typecast(messageDigest.digest(),'uint8');
digest = lower(reshape(dec2hex(rawDigest,2).',1,[]));
end
