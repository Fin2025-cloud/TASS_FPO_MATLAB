function h=paper_hash(value,kind)
%PAPER_HASH SHA-256 of UTF-8 text or exact file bytes.
if nargin<2,kind='text';end
if strcmp(kind,'file')
 f=fopen(value,'rb');if f<0,error('paper:Read','Cannot read %s.',value);end
 c=onCleanup(@()fclose(f)); bytes=fread(f,inf,'*uint8'); clear c;
else
 bytes=unicode2native(char(value),'UTF-8');
end
if exist('OCTAVE_VERSION','builtin')
 h=hash('sha256',char(bytes(:)'));
else
 md=javaMethod('getInstance','java.security.MessageDigest','SHA-256');
 md.update(typecast(uint8(bytes(:)),'int8')); raw=typecast(md.digest(),'uint8');
 h=lower(reshape(dec2hex(raw,2)',1,[]));
end
end
