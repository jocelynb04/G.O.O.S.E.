function root = concept2_project_root()
%CONCEPT2_PROJECT_ROOT Locate the Concept 2 project beside this helper.
    root=fileparts(mfilename('fullpath'));
    assert(isfile(fullfile(root,'setup_concept2.m')), ...
        'concept2_project_root:MissingRoot','Project setup file not found.');
end
