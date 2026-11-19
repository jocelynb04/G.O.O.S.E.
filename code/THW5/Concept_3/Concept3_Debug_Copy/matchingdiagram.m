function analysis = matchingdiagram()
%MATCHINGDIAGRAM Plot the Concept 3 constraint limits and return their data.
    obj = ttpa_disciplines();
    settings = obj.constraint_settings;
    sweep = settings.wing_loading_range_psf;
    WS_sweep = linspace(sweep(1), sweep(2), settings.wing_loading_points);

    [WP_limits, ~, names] = run_constraints(WS_sweep, obj);
    [WP_envelope, WS_wall, driving, WS_best, WP_best] = matching_envelope(WS_sweep, obj);
    caravan = settings.design_point;
    W_TO = obj.sizing.W_TO_guess_lbf;
    concept3 = struct('wing_loading_psf', W_TO / obj.geom.S_ref, ...
        'power_loading_lb_per_hp', W_TO / obj.prop.P_SL);

    % Build a plotting x-vector that reaches WS_wall if it lies beyond sweep(2)
    xmax_plot = sweep(2);
    if isfinite(WS_wall) && WS_wall > xmax_plot
        xmax_plot = WS_wall;
    end
    WS_plot = linspace(sweep(1), xmax_plot, settings.wing_loading_points);
    if isfinite(WS_wall) && WS_wall >= sweep(1) && WS_wall <= xmax_plot
        WS_plot = unique([WS_plot, WS_wall]);
    end
    [WP_limits_plot, ~, names_plot] = run_constraints(WS_plot, obj);

    figure('Name', 'Concept 3 Matching Diagram', 'Color', 'w');
    hold on;
    grid on;

    % Include the wall itself in the fill when it falls inside the plotted range.
    feasible_WS = WS_plot(WS_plot <= WS_wall);
    if isfinite(WS_wall) && WS_wall > sweep(1) && WS_wall < xmax_plot
        feasible_WS = unique([feasible_WS, WS_wall]);
    end
    if numel(feasible_WS) > 1
        feasible_WP = matching_envelope(feasible_WS, obj);
        fill([feasible_WS, fliplr(feasible_WS)], ...
            [feasible_WP, zeros(size(feasible_WS))], [0.7, 0.9, 0.7], ...
            'FaceAlpha', 0.4, 'EdgeColor', 'none', 'DisplayName', 'Feasible region');
    end

    for k = find(~all(isnan(WP_limits_plot), 2)).'
        plot(WS_plot, WP_limits_plot(k,:), 'LineWidth', 1.5, 'DisplayName', names_plot(k));
    end
    if isfinite(WS_wall)
        xline(WS_wall, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Landing wing-loading limit');
    end
    % The two points are close at this scale. Use a ring around the reference.
    plot(caravan.wing_loading_psf, caravan.power_loading_lb_per_hp, 'o', ...
        'MarkerEdgeColor', [0.75 0.15 0.15], 'MarkerSize', 12, 'LineWidth', 1.4, ...
        'DisplayName', 'Caravan reference');
    
    if isfinite(WS_best)
        plot(WS_best, WP_best, 'kp', 'MarkerFaceColor', 'y', ...
            'MarkerSize', 10, 'DisplayName', 'Minimum installed power point');
    end

    xlabel('Wing loading W/S [lbf/ft^2]');
    ylabel('Power loading W/P [lbf/hp]');
    title('Concept 3 Seaplane Matching Diagram');
    xmax = max([sweep(2), caravan.wing_loading_psf, concept3.wing_loading_psf, ...
        WS_wall(isfinite(WS_wall))]);
    xlim([20, xmax * 1.05]);
    ylim([0, inf]);
    legend('Location', 'best');
    hold off;

    analysis = struct('WS_sweep', WS_sweep, 'WP_limits', WP_limits, ...
        'condition_names', names, 'WP_envelope', WP_envelope, ...
        'WS_wall', WS_wall, 'driving', driving, 'WS_best', WS_best, ...
        'WP_best', WP_best, 'design_point', caravan, ...
        'concept3_design_point', concept3);
end
