% RUN_CONSTRAINT_ANALYSIS  Generates the matching diagram (constraint analysis)
%                          for Concept 3 (Series-Hybrid Seaplane).

clear; clc; close all;

% --- 1. Initialize Discipline Bundle with Concept 3 JSON ---
json_path = 'concept3.json';
obj = ttpa_disciplines(json_path);

% --- 2. Define Wing Loading Sweep Range ---
WS_min = obj.cons.wing_loading_range_psf(1);
WS_max = obj.cons.wing_loading_range_psf(2);
n_points = obj.cons.wing_loading_points;
WS_sweep = linspace(WS_min, WS_max, n_points);

% --- 3. Compute Matching Envelope ---
% matching_envelope evaluates all constraints (takeoff, climbs, cruise, landing)
[WP_matrix, WS_wall, condition_names, WS, WP] = matching_envelope(WS_sweep, obj);

% --- 4. Plotting the Matching Diagram ---
figure('Name', 'Concept 3 Matching Diagram', 'Color', 'w', 'Position', [100, 100, 850, 650]);
hold on; grid on;

% Colors for the constraint curves
colors = lines(size(WP_matrix, 1));

for i = 1:size(WP_matrix, 1)
    plot(WS_sweep, WP_matrix(i, :), 'LineWidth', 2, 'Color', colors(i, :));
end

% Plot Wing Loading Wall (Landing / Stall limit vertical dashed line)
line([WS_wall, WS_wall], [0, 60], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5);

% --- 5. Shade the Feasible Region ---
% The feasible region is bounded below by the maximum power loading required 
% and to the left by the wing-loading wall.
WP_envelope = max(WP_matrix, [], 1);
fill([WS_sweep, fliplr(WS_sweep)], [WP_envelope, zeros(size(WS_sweep))], ...
     [0.7, 0.9, 0.7], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% --- 6. Plot Design Point & Best Point ---
% Read design point from JSON configuration
dp_WS = obj.cons.design_point.wing_loading_psf;
dp_WP = obj.cons.design_point.power_loading_lb_per_hp;

plot(dp_WS, dp_WP, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot(WS, WP, 'yp', 'MarkerSize', 10, 'MarkerFaceColor', 'y'); % Best vertex point

% --- 7. Formatting and Legend ---
xlabel('Wing Loading $W/S$ [lbf/ft$^2$]', 'Interpreter', 'latex', 'FontSize', 12);
ylabel('Power Loading $W/P$ [lbf/hp]', 'Interpreter', 'latex', 'FontSize', 12);
title('Concept 3 Seaplane Matching Diagram', 'FontSize', 14, 'FontWeight', 'bold');
axis([0, 60, 0, 60]);

legend_entries = [condition_names, {'Wing Loading Wall', 'Feasible Region', 'Design Point', 'Best Vertex Point'}];
legend(legend_entries, 'Location', 'northeast', 'FontSize', 9);

hold off;