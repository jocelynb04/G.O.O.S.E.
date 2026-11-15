function plot_concept4_results(folder)
if nargin < 1 || isempty(folder)
    folder = fullfile(fileparts(mfilename('fullpath')),'results');
end
history_path = fullfile(folder,'sizing_history.csv');
if isfile(history_path)
    T = readtable(history_path);
    f = figure('Visible','off');
    plot(T.iteration,T.W_TO_lb,'-o','LineWidth',1);
    xlabel('Sizing iteration'); ylabel('Takeoff gross weight (lb)');
    title('Concept 4 preliminary weight convergence'); grid on;
    saveas(f,fullfile(folder,'sizing_weight_convergence.png'));
    close(f);
end
mission_path = fullfile(folder,'mission_segments.csv');
if isfile(mission_path)
    T = readtable(mission_path);
    time = [0;cumsum(T.duration_min)];
    soc = [T.soc_start(1);T.soc_end]*100;
    f = figure('Visible','off');
    plot(time,soc,'-o','LineWidth',1);
    xlabel('Elapsed mission time (min)'); ylabel('Battery SOC (%)');
    title('Concept 4 preliminary mission battery SOC'); ylim([0,100]); grid on;
    saveas(f,fullfile(folder,'mission_soc.png'));
    close(f);
end
matching_path = fullfile(folder,'matching_diagram_data.csv');
if isfile(matching_path)
    T = readtable(matching_path);
    [ws,ii] = sort(T.wing_loading_psf);
    f = figure('Visible','off');
    hold on;
    plot(ws,T.roc_2000_sl_hp(ii),'LineWidth',1);
    plot(ws,T.roc_500_10k_hp(ii),'LineWidth',1);
    plot(ws,T.roc_450_oei_hp_NO_FAILURE_DRAG(ii),'LineWidth',1);
    plot(ws,T.cruise_180_hp(ii),'LineWidth',1);
    plot(ws,T.required_motor_hp(ii),'LineWidth',1.5);
    hold off;
    xlabel('Wing loading W/S (lb/ft^2)'); ylabel('Motor shaft power (hp)');
    title('Concept 4 preliminary matching power sweep');
    legend('2000 fpm SL','500 fpm 10000 ft','450 fpm OEI without failure drag', ...
        '180 KTAS cruise','Installed motor rating','Location','best');
    grid on;
    saveas(f,fullfile(folder,'matching_power_sweep.png'));
    close(f);
end
end
