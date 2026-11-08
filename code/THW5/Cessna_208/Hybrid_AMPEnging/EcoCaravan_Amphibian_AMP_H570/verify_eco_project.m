function verify_eco_project()
root=setup_eco_paths();
out=fullfile(root,'outputs');
if ~isfolder(out), mkdir(out); end
report=fullfile(out,'AMP_H570_VERIFICATION.txt'); fid=fopen(report,'w'); assert(fid>=0); fclose(fid);
diary(report); cleanup=onCleanup(@() diary('off'));
fprintf('MATLAB %s\n',version);
files=dir(fullfile(root,'**','*.m'));
for k=1:numel(files)
    issues=checkcode(fullfile(files(k).folder,files(k).name),'-id');
    assert(~any(ismember({issues.id},{'PARSE','SYNER'})),'Hybrid:Syntax','Syntax diagnostics in %s',files(k).name);
end
results=runtests(fullfile(root,'tests')); disp(results); assertSuccess(results);
[~,products]=matlab.codetools.requiredFilesAndProducts(fullfile(root,'run_eco_caravan.m')); disp({products.Name});
r=run_eco_caravan([],true); assert(r.feasible);
axes_list=findall(gcf,'Type','axes');
for k=1:numel(axes_list), axes_list(k).Toolbar.Visible='off'; end
exportgraphics(gcf,fullfile(out,'AMP_H570_mission.png'),'Resolution',150);
save(fullfile(out,'AMP_H570_results.mat'),'r','results');
fprintf('AMP-H570 verification complete.\n');
end
