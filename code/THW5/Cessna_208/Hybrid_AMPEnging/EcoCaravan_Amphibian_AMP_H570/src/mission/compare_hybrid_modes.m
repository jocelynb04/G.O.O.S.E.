function comparison=compare_hybrid_modes()
% Same loaded aircraft, same trajectory, same hardware, different energy-source schedule.
root=eco_project_root();
comparison.hybrid=hybrid_mission(fullfile(root,'config','Hybrid_requirements.json'));
comparison.fuel_only=hybrid_mission(fullfile(root,'config','scenarios','Hybrid_fuel_only.json'));
comparison.both_feasible=comparison.hybrid.feasible && comparison.fuel_only.feasible;
if comparison.both_feasible
    comparison.fuel_saved_lb=comparison.fuel_only.fuel_used_lb-comparison.hybrid.fuel_used_lb;
    fprintf('Same-aircraft comparison: fuel-only %.2f lb; hybrid %.2f lb; fuel displaced %.2f lb\n', ...
        comparison.fuel_only.fuel_used_lb,comparison.hybrid.fuel_used_lb,comparison.fuel_saved_lb);
else
    comparison.fuel_saved_lb=NaN;
    fprintf('Comparison incomplete; inspect each scenario failure.\n');
end
end
