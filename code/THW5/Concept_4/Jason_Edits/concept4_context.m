function [obj,J,A]=concept4_context()
%CONCEPT4_CONTEXT Local-only inputs with OpenVSP geometry as the baseline.
root=fileparts(mfilename('fullpath'));addpath(root,'-begin');
J=jsondecode(fileread(fullfile(root,'concept4_aero_hydro_requirements.json')));
A=jsondecode(fileread(fullfile(root,'Concept4_integration_assumptions.json')));
p=SeaplaneProp_Concept4(J);g=SeaplaneGeom(J,p);a=SeaplaneAero_Concept4(J,g);
obj=struct('prop',p,'geom',g,'aero',a,'weights',SeaplaneWeights(J,g,p), ...
 'hydro',SeaplaneHydro_Concept4(J,g,a),'mission',Concept4Mission(J,g,a,p,A));
end
