function figures=plot_concept4_results(folder)
% Replot current data, never load historical candidate results implicitly.
root=fileparts(mfilename('fullpath'));
if nargin<1,folder=fullfile(root,'Results','Current');end
data=load(fullfile(folder,'concept4_study.mat'),'analysis');
figures=plot_concept4_constraints(data.analysis.constraints,folder,true);
end
