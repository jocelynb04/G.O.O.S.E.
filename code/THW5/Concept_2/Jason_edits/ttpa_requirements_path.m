function p = ttpa_requirements_path()
%TTPA_REQUIREMENTS_PATH Absolute path to the active concept2.json input.
% The turbine catalog stays beside this file for relative catalog lookup.
    p=string(fullfile(concept2_project_root(),'concept2.json'));
end
