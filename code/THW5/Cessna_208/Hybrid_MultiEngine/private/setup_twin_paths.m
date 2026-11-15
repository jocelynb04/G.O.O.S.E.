function [root,restorePath,shared]=setup_twin_paths()
% Restore the caller's MATLAB path when the entry point returns.
root=fileparts(fileparts(mfilename('fullpath')));
shared=fullfile(fileparts(root),'Hybrid_AMPEnging','EcoCaravan_Amphibian_AMP_H570');
sharedSource=fullfile(shared,'src');
assert(isfolder(sharedSource),'TwinHybrid:Dependency', ...
    'Keep this folder beside Hybrid_AMPEnging in the checkout.');
originalPath=path;
restorePath=onCleanup(@() path(originalPath));
addpath(genpath(sharedSource),fullfile(root,'src'),'-begin');
end
