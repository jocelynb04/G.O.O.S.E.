function [p] = ttpa_requirements_path()
%TTPA_REQUIREMENTS_PATH  Absolute path to the Concept 2 requirements JSON.
%
%   p = ttpa_requirements_path() returns Ttpa_requirements_Concept2.json.
%
%   Resolves Inputs/Ttpa_requirements_Concept2.json from the project root,
%   independent of MATLAB's current working directory. The engine catalog
%   remains beside this file for requirements-relative catalog lookup.

    p = string(fullfile(concept2_project_root(), 'Inputs', ...
        'Ttpa_requirements_Concept2.json'));

end
