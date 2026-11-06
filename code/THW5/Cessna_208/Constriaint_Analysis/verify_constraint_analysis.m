function verify_constraint_analysis()
root=setup_project(); out=fullfile(root,'outputs'); if ~isfolder(out), mkdir(out); end
report=fullfile(out,'CONSTRAINT_VERIFICATION.txt'); fid=fopen(report,'w'); assert(fid>=0); fclose(fid);
diary(report); cleanup=onCleanup(@() diary('off'));
fprintf('MATLAB %s\n',version);
files=dir(fullfile(root,'**','*.m'));
for k=1:numel(files)
    issues=checkcode(fullfile(files(k).folder,files(k).name),'-id');
    assert(~any(ismember({issues.id},{'PARSE','SYNER'})),'Constraints:Syntax','Syntax diagnostics in %s',files(k).name);
end
results=runtests(fullfile(root,'tests')); disp(results); assertSuccess(results);
[~,products]=matlab.codetools.requiredFilesAndProducts(fullfile(root,'run_constraint_analysis.m')); disp({products.Name});
r=run_constraint_analysis([],true);
save(fullfile(out,'constraint_analysis_results.mat'),'r','results');
fprintf('Constraint verification complete.\n');
end
