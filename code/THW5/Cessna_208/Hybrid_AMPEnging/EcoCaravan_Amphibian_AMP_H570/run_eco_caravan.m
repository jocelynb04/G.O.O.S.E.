function result=run_eco_caravan(path,make_plots)
% Run selectable-source parallel hybrid demonstration.
root=setup_eco_paths();
if nargin<1 || isempty(path), path=fullfile(root,'config','AMP_H570_requirements.json'); end
if nargin<2, make_plots=true; end
result=eco_mission(path);
J=jsondecode(fileread(path));
result.cruise_check=eco_cruise_check(J,result.initial_weight_lb);
fprintf('Cruise screen at 97.5%% of loaded takeoff weight, without boost or charging load:\n');
disp(result.cruise_check);
fprintf('Hybrid empty weight %.1f lb; added equipment %.1f lb; takeoff weight %.1f lb\n', ...
    result.hybrid_empty_lb,result.added_system_mass_lb,result.initial_weight_lb);
fprintf('Feasible schedule: %d; fuel used %.1f lb; battery used %.2f kWh; final SOC %.1f%%\n', ...
    result.feasible,result.fuel_used_lb,result.battery_used_kWh,100*result.final_soc);
if ~result.feasible, fprintf('Stopped in %s: %s\n',result.failure_segment,result.failure); end
if ~isempty(result.segments), disp(struct2table(result.segments)); end
fprintf('Battery discharged %.2f kWh; recharged %.2f kWh; net used %.2f kWh\n', ...
    result.battery_discharged_kWh,result.battery_recharged_kWh,result.battery_used_kWh);
if make_plots
    figure('Name','AMP-H570 conceptual amphibian mission');
    tiledlayout(4,1);
    nexttile; plot(result.trace.time_min,100*result.trace.soc,'LineWidth',1.5);
    ylabel('Battery SOC (%)'); grid on;
    nexttile; plot(result.trace.time_min,result.trace.fuel_remaining_lb,'LineWidth',1.5);
    ylabel('Fuel remaining (lb)'); grid on;
    nexttile; plot(result.trace.time_min,result.trace.combustion_hp, ...
        result.trace.time_min,result.trace.electric_shaft_kW/0.745699872,'LineWidth',1.2);
    ylabel('Shaft power (hp)'); legend('Combustion incl. generation','Electric motor'); grid on;
    nexttile; plot(result.trace.time_min,result.trace.battery_kW,'LineWidth',1.2);
    yline(0,':'); ylabel('Battery kW (+ draw)'); xlabel('Elapsed time (min)'); grid on;
end
end
