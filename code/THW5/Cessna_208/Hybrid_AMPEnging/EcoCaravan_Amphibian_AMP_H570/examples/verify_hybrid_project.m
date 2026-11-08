function verify_hybrid_project()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'src')),'-begin');
out=fullfile(root,'outputs');
if ~isfolder(out), mkdir(out); end
report=fullfile(out,'HYBRID_VERIFICATION.txt'); fid=fopen(report,'w'); assert(fid>=0); fclose(fid);
diary(report); cleanup=onCleanup(@() diary('off'));
fprintf('MATLAB %s\n',version);
files=[dir(fullfile(root,'*.m'));dir(fullfile(root,'tests','*.m'))];
for k=1:numel(files)
    issues=checkcode(fullfile(files(k).folder,files(k).name),'-id');
    assert(~any(ismember({issues.id},{'PARSE','SYNER'})),'Hybrid:Syntax','Syntax diagnostics in %s',files(k).name);
end
results=runtests(fullfile(root,'tests')); disp(results); assertSuccess(results);
[~,products]=matlab.codetools.requiredFilesAndProducts(fullfile(root,'examples','run_hybrid_caravan.m')); disp({products.Name});
r=run_hybrid_caravan([],true); assert(r.feasible);
comparison=compare_hybrid_modes(); assert(comparison.both_feasible);
exportgraphics(gcf,fullfile(out,'hybrid_mission.png'),'Resolution',150);
save(fullfile(out,'hybrid_demo_results.mat'),'r','comparison','results');
fprintf('Hybrid verification complete.\n');
end
