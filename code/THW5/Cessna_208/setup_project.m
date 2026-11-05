function root = setup_project()
%SETUP_PROJECT Add this checkout's runtime folders using absolute paths.
root = fileparts(mfilename('fullpath'));
addpath(root,'-begin');
folders = {'models','framework','io','mission','constraints','sizing','reference','analysis'};
for k=1:numel(folders)
    folder=fullfile(root,'src',folders{k});
    if isfolder(folder), addpath(folder,'-begin'); end
end
end
