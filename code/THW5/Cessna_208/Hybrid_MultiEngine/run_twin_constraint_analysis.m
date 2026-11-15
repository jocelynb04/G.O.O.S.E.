function analysis=run_twin_constraint_analysis(configPath,makePlot)
%RUN_TWIN_CONSTRAINT_ANALYSIS Plot wing loading versus twin hybrid power loading.
[root,restorePath,shared]=setup_twin_paths(); %#ok<NASGU>
if nargin<1 || isempty(configPath)
    configPath=fullfile(root,'config','twin_hybrid.json');
end
if nargin<2, makePlot=true; end
config=jsondecode(fileread(configPath));
reference=jsondecode(fileread(fullfile(shared,'docs','reference','CONVENTIONAL_CONSTRAINT_INPUTS.json')));
analysis=twin_constraint_analysis(config,reference);
disp(analysis.reference_power);
fprintf('Loaded twin reference: W/S %.2f lbf/ft^2, W/P %.2f lbf/shp at %.1f shp pack-limited peak\n', ...
    analysis.reference.WS,analysis.reference.WP,analysis.reference.peak_shp);
fprintf('Water landing proxy wall %.2f lbf/ft^2. Reference passes primary screen: %d\n', ...
    analysis.water_wall,analysis.reference.passes_primary_screen);
if makePlot
    fig=plot_twin_constraints(analysis);
    out=fullfile(root,'outputs');
    if ~isfolder(out), mkdir(out); end
    exportgraphics(fig,fullfile(out,'twin_hybrid_constraints.png'),'Resolution',180);
    exportgraphics(fig,fullfile(out,'twin_hybrid_constraints.pdf'),'ContentType','vector');
end
end
