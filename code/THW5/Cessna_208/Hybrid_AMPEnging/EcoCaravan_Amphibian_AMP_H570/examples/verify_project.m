function verify_project()
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'src')),'-begin');
out=fullfile(root,'outputs');
if ~isfolder(out), mkdir(out); end
report = fullfile(out,'MATLAB_VERIFICATION.txt');
fid = fopen(report,'w'); assert(fid>=0); fclose(fid);
diary(report); cleanup = onCleanup(@() diary('off'));
fprintf('MATLAB %s\n',version);
files = dir(fullfile(root,'*.m')); syntaxErrors = 0;
for k=1:numel(files)
    issues = checkcode(fullfile(root,files(k).name),'-id');
    for j=1:numel(issues)
        if any(strcmp(issues(j).id,{'PARSE','SYNER'})), disp(issues(j)); syntaxErrors=syntaxErrors+1; end
    end
end
assert(syntaxErrors==0);
results = runtests(fullfile(root,'tests')); disp(results); assertSuccess(results);
[deps,products] = matlab.codetools.requiredFilesAndProducts(fullfile(root,'examples','run_caravan.m'));
disp({products.Name}); fprintf('Resolved dependency files: %d\n',numel(deps));
r = run_caravan(true); fprintf('Sizing converged: %d in %d passes\n',r.converged,r.state.n_iter);
disp(r.state); save(fullfile(out,'verification_results.mat'),'r','results');
end
