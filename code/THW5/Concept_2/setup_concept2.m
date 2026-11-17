function root = setup_concept2(include_supplemental)
%SETUP_CONCEPT2 Add active analysis code; optionally enable tests/extra tools.
% Run from the project folder. Paths resolve from this file, not the cwd.
    if nargin<1, include_supplemental=false; end
    validateattributes(include_supplemental,{'logical'},{'scalar'});
    root=fileparts(mfilename('fullpath'));
    addpath(root,genpath(fullfile(root,'Analysis')));
    if include_supplemental
        for name={'Tests','Studies','Legacy'}
            addpath(genpath(fullfile(root,'Supplemental',name{1})));
        end
    end
end
