function root = setup_concept2(include_supplemental)
%SETUP_CONCEPT2 Enable Concept 2 models and shared framework helpers.
    if nargin<1, include_supplemental=false; end
    validateattributes(include_supplemental,{'logical'},{'scalar'});
    root=fileparts(mfilename('fullpath'));
    addpath(root,fullfile(root,'framework'));
    if include_supplemental
        for name={'Tests','Studies','Legacy'}
            folder=fullfile(root,'Supplemental',name{1});
            if isfolder(folder), addpath(genpath(folder)); end
        end
    end
end
