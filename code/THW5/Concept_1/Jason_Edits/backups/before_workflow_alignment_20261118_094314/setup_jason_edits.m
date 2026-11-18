function setup_jason_edits(frameworkDir)
%SETUP_JASON_EDITS Add the Concept 1 copy and its IHW3 course framework.
arguments
    frameworkDir (1,1) string = ""
end
here = fileparts(mfilename('fullpath'));
if strlength(frameworkDir) == 0
    existing = which('AircraftState');
    if ~isempty(existing)
        frameworkDir = string(fileparts(existing));
    end
    parent = here;
    while true
        candidate = fullfile(parent, 'IHW3', 'student_starter');
        if isfile(fullfile(candidate, 'AircraftState.m'))
            frameworkDir = string(candidate);
            break
        end
        next = fileparts(parent);
        if strcmp(next, parent)
            break
        end
        parent = next;
    end
end
assert(isfile(fullfile(frameworkDir, 'AircraftState.m')), ...
    'Pass the path to IHW3/student_starter as frameworkDir.');
addpath(char(frameworkDir), here);
end
