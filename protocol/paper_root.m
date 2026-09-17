function root=paper_root()
%PAPER_ROOT Resolve this project's root, independent of pwd.
root=fileparts(fileparts(mfilename('fullpath')));
end

