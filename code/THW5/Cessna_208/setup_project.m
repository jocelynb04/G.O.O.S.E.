function root = setup_project()
%SETUP_PROJECT Add this checkout's runtime folders using absolute paths.
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
folders = {'models','framework','io','mission','constraints','sizing','reference','analysis'};
sourceRoot=fullfile(root,'src');
if ~isfolder(sourceRoot)
    sourceRoot=fullfile(root,'Constriaint_Analysis','src');
end
for k=1:numel(folders)
    folder=fullfile(sourceRoot,folders{k});
    if isfolder(folder), addpath(folder,'-begin'); end
end
end
