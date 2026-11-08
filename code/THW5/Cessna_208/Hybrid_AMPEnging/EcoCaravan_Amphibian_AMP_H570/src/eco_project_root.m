function root=eco_project_root()
%ECO_PROJECT_ROOT Resolve project inputs independently of the current folder.
root=fileparts(fileparts(mfilename('fullpath')));
end
