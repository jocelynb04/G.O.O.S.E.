function root = concept2_project_root()
%CONCEPT2_PROJECT_ROOT Locate the repository from Analysis/Utilities.
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    assert(isfile(fullfile(root,'setup_concept2.m')), ...
        'concept2_project_root:MissingRoot','Project setup file not found.');
end
