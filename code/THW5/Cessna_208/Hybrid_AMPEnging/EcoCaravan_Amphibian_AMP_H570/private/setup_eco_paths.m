function root=setup_eco_paths()
% Set up the source path for the two project entry points.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'src')),'-begin');
end
