function result = run_constraint_analysis(config_path,make_plots)
%RUN_CONSTRAINT_ANALYSIS Plot W_TO/S versus W_TO/P_SL for the conventional amphibian.
root=setup_project();
if nargin<1 || isempty(config_path), config_path=fullfile(root,'config','Constraint_analysis.json'); end
if nargin<2, make_plots=true; end
c=jsondecode(fileread(config_path)); result=caravan_constraint_analysis(c);
out=fullfile(root,'outputs'); if ~isfolder(out), mkdir(out); end
fprintf('Conventional Grand Caravan EX Amphibian / PT6A-140, no hybrid\n');
fprintf('Climb: %s requirement at %.0f and %.0f ft\n',c.climb_requirement_type,c.climb_altitudes_ft);
fprintf('At reference W/S: climb speeds %.1f / %.1f KTAS; implied ROC %.1f / %.1f ft/min\n', ...
    result.reference.climb_speed_ktas,result.reference.required_climb_roc_fpm);
fprintf('Water landing wall %.2f lb/ft2, CALIBRATED PROXY; inferred deceleration %.3f g\n', ...
    result.WS_water_wall,result.water.effective_deceleration_g);
for k=1:numel(result.cases)
    s=result.cases(k);
    fprintf('%.0f KTAS at %.0f ft: reference cruise needs %.1f shp, available %.1f shp; passes AEO set: %d\n', ...
        s.speed_ktas,c.cruise_altitude_ft,s.reference_cruise_power_required_shp,s.reference_cruise_power_available_shp,s.reference_meets_aeo_constraints);
    if s.above_published_cruise_benchmark, fprintf('  Above the published 164-KTAS amphibian maximum-cruise benchmark; not a validated capability.\n'); end
    if s.selected.exists
        fprintf('  Additional sizing candidate (not the plotted comparator): W/S %.2f, W/P %.2f, S %.1f ft2, P %.1f shp; margin applied %d\n', ...
            s.selected.WS,s.selected.WP,s.selected.S_ft2,s.selected.P_shp,s.selected.margin_applied);
    elseif s.above_published_cruise_benchmark && s.candidate.exists
        fprintf('  Simplified power equations admit a numerical candidate, but %.0f-KTAS capability is not supported by the published benchmark.\n',s.speed_ktas);
    else, fprintf('  No feasible screening point within the sweep, water wall and %.0f-shp maximum.\n',c.max_installed_power_shp); end
end
fprintf('OEI: positive powered climb impossible. Approximate stopped-prop glide L/D %.2f, speed %.1f KTAS, sink %.0f ft/min.\n', ...
    result.oei_glide.LD,result.oei_glide.best_glide_ktas,result.oei_glide.sink_fpm);
% Report the current-design margins using the same active envelope as the plot.
plot_speed=164; if isfield(c,'plot_required_cruise_ktas'), plot_speed=c.plot_required_cruise_ktas; end
plot_index=find([result.cases.speed_ktas]==plot_speed,1);
assert(~isempty(plot_index),'Constraints:PlotSpeed','The required plotting speed must have a calculated cruise curve.');
limit=interp1(result.WS,result.cases(plot_index).envelope,result.reference.WS);
result.chart_design_point=struct('WS',result.reference.WS,'WP',result.reference.WP, ...
    'active_cruise_constraint_ktas',plot_speed,'allowable_WP',limit, ...
    'power_loading_margin_fraction',(limit-result.reference.WP)/limit, ...
    'wing_loading_margin_fraction',(result.WS_water_wall-result.reference.WS)/result.WS_water_wall, ...
    'numerically_feasible',result.reference.WP<=limit && result.reference.WS<=result.WS_water_wall);
fprintf('Caravan comparator point against %.0f-KTAS target: numerical pass %d; W/P margin %.2f%%; water-wall W/S margin %.2f%%.\n', ...
    plot_speed,result.chart_design_point.numerically_feasible,100*result.chart_design_point.power_loading_margin_fraction, ...
    100*result.chart_design_point.wing_loading_margin_fraction);
if make_plots
    fig=plot_caravan_constraints(result);
    exportgraphics(fig,fullfile(out,'caravan_constraint_diagram.png'),'Resolution',180);
    exportgraphics(fig,fullfile(out,'caravan_constraint_diagram.pdf'),'ContentType','vector');
    savefig(fig,fullfile(out,'caravan_constraint_diagram.fig'));
end
T=table(result.WS',result.climb_limits(1,:)',result.climb_limits(2,:)',result.balked_limit', ...
    'VariableNames',{'WS_lbf_ft2','climb_SL_WP','climb_10000ft_WP','balked_WP'});
for k=1:numel(result.cases)
    T.(sprintf('cruise_%gkt_WP',result.cases(k).speed_ktas))=result.cases(k).cruise_limit';
end
writetable(T,fullfile(out,'constraint_curve_data.csv'));
save(fullfile(out,'constraint_analysis_results.mat'),'result');
end
