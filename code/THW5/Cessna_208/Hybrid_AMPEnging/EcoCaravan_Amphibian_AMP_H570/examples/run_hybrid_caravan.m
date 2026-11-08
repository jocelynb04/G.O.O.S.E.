function result=run_hybrid_caravan(path,make_plots)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root,'src')),'-begin');
% Run selectable-source parallel hybrid demonstration.
if nargin<1 || isempty(path), path=fullfile(root,'config','Hybrid_requirements.json'); end
if nargin<2, make_plots=true; end
result=hybrid_mission(path);
fprintf('Hybrid empty weight %.1f lb; added equipment %.1f lb; takeoff weight %.1f lb\n', ...
    result.hybrid_empty_lb,result.added_system_mass_lb,result.initial_weight_lb);
fprintf('Feasible schedule: %d; fuel used %.1f lb; battery used %.2f kWh; final SOC %.1f%%\n', ...
    result.feasible,result.fuel_used_lb,result.battery_used_kWh,100*result.final_soc);
if ~result.feasible, fprintf('Stopped: %s\n',result.failure); end
if ~isempty(result.segments), disp(struct2table(result.segments)); end
if make_plots
    figure('Name','Parallel hybrid Caravan mission');
    tiledlayout(3,1);
    nexttile; plot(result.trace.time_min,100*result.trace.soc,'LineWidth',1.5);
    ylabel('Battery SOC (%)'); grid on;
    nexttile; plot(result.trace.time_min,result.trace.fuel_remaining_lb,'LineWidth',1.5);
    ylabel('Fuel remaining (lb)'); grid on;
    nexttile; plot(result.trace.time_min,result.trace.turbine_hp, ...
        result.trace.time_min,result.trace.electric_shaft_kW/0.745699872,'LineWidth',1.2);
    ylabel('Shaft power (hp)'); xlabel('Elapsed time (min)'); legend('Turbine','Electric motor'); grid on;
end
end
