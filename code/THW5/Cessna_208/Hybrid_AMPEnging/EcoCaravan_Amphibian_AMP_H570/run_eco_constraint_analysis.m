function analysis=run_eco_constraint_analysis(config_path,make_plots)
%RUN_ECO_CONSTRAINT_ANALYSIS Plot the AMP-H570 amphibian mission constraints.
root=setup_eco_paths();
if nargin<1 || isempty(config_path)
    config_path=fullfile(root,'config','AMP_H570_requirements.json');
end
if nargin<2, make_plots=true; end
analysis=eco_constraint_analysis(config_path);
r=analysis.reference;
fprintf('AMP-H570 reference: %.1f lb, %.1f ft^2, %.0f shp peak; W/S %.2f, W/P %.2f\n', ...
    r.weight_lb,r.wing_area_ft2,r.peak_shp,r.WS,r.WP);
fprintf('Landing: %.1f lb, %.1f%% of takeoff weight, %.1f%% SOC; water proxy wall %.2f lb/ft^2\n', ...
    r.landing_weight_lb,100*r.landing_beta,100*r.landing_SOC,analysis.WS_water_wall);
fprintf('Implied climb rates at reference W/S:');
fprintf(' %.0f ft/min',r.implied_climb_ROC_fpm);
fprintf('\n');
disp(analysis.reference_power);
fprintf('Reference passes %.0f-KTAS constraint set: %d. Passes with comparator cruise: %d.\n', ...
    analysis.cruise_check.Speed_KTAS(1),r.passes_primary_screen,r.passes_comparison_screen);
fprintf('Total propulsion loss: no powered climb. Combustion-loss electric upper bound %.1f shp.\n', ...
    analysis.combustion_loss_electric_upper_bound_shp);
if make_plots
    fig=plot_eco_constraints(analysis);
    out=fullfile(root,'outputs');
    if ~isfolder(out), mkdir(out); end
    exportgraphics(fig,fullfile(out,'AMP_H570_constraint_diagram.png'),'Resolution',180);
    exportgraphics(fig,fullfile(out,'AMP_H570_constraint_diagram.pdf'),'ContentType','vector');
end
end
