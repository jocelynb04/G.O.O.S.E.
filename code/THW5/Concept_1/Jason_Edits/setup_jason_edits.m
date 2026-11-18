function setup_jason_edits(frameworkDir)
%SETUP_JASON_EDITS Add this Concept 1 copy and its own framework first.
arguments
    frameworkDir (1,1) string = ""
end
here = fileparts(mfilename('fullpath'));
if strlength(frameworkDir) == 0
    local = fullfile(here,'framework');
    if isfile(fullfile(local,'AircraftState.m'))
        addpath(local,here,'-begin');
        return
    end
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
