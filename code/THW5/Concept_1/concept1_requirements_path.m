function [p] = concept1_requirements_path()
%CONCEPT1_REQUIREMENTS_PATH  Absolute path to the Concept 1 requirements JSON.
%
%   p = concept1_requirements_path() returns the first of these that exists,
%   looking in this folder, the folder above, the current folder, its parent,
%   and finally anywhere on the MATLAB path:
%
%       Concept1_requirements.json
%       Concept1_requirements_template.json
%
%   Use this instead of ttpa_requirements_path for Concept 1. The TTPA file
%   lacks the Concept 1 blocks (propulsion.turboprop_*, geometry.concept1,
%   weights.concept1) and carries the TTPA mission, payload and BSFC, so the
%   Concept 1 classes would silently fall back to their defaults.

    here  = fileparts(mfilename('fullpath'));
    names = ["Concept1_requirements.json", ...
             "Concept1_requirements_template.json"];
    dirs  = {here, fullfile(here, '..'), pwd, fullfile(pwd, '..')};

    for d = 1:numel(dirs)
        for n = 1:numel(names)
            f = fullfile(dirs{d}, names(n));
            if isfile(f)
                p = string(f);
                return;
            end
        end
    end

    % Last resort: anywhere on the MATLAB path.
    for n = 1:numel(names)
        f = which(char(names(n)));
        if ~isempty(f)
            p = string(f);
            return;
        end
    end

    error('concept1_requirements_path:NotFound', ...
        ['Neither Concept1_requirements.json nor ', ...
         'Concept1_requirements_template.json was found next to this file, ', ...
         'in the current folder, or on the MATLAB path. Copy the JSON into ', ...
         'the folder that holds the Concept 1 .m files.']);
end
