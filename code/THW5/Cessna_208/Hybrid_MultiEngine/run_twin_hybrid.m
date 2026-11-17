function result=run_twin_hybrid(configPath,makePlot)
%RUN_TWIN_HYBRID Run the twin AMP-H570 amphibian concept and installation screen.
[root,restorePath]=setup_twin_paths(); %#ok<NASGU>
if nargin<1 || isempty(configPath)
    configPath=fullfile(root,'config','twin_hybrid.json');
end
if nargin<2, makePlot=true; end
config=jsondecode(fileread(configPath));
result=twin_hybrid_mission(config);
result.installation=twin_installation_screen(config,result.initial_weight_lb);
disp(result.weight_breakdown);
fprintf('Empty %.1f lb, takeoff %.1f lb, inherited MTOW margin %.1f lb\n', ...
    result.hybrid_empty_lb,result.initial_weight_lb,result.mtow_margin_lb);
fprintf('At 800 lb payload, usable fuel by weight/tank limit is %.1f lb\n', ...
    max(0,result.fuel_capacity_at_800_lb_payload_lb));
fprintf('Nosecone usable volume estimate %.1f ft^3, propeller-to-fuselage lateral gap %.2f ft\n', ...
    result.installation.nose_usable_ft3,result.installation.propeller_fuselage_gap_ft);
fprintf('Mission pass %d, fuel used %.1f lb, end SOC %.1f%% per side\n', ...
    result.feasible,result.fuel_used_lb,100*result.final_soc);
if result.feasible
    disp(struct2table(result.segments));
else
    fprintf('Stopped in %s: %s\n',result.failure_segment,result.failure);
end
disp(result.installation.climb_screen);
if makePlot, plot_twin_hybrid(result); end
end
