%% RUN_CONCEPT1_CONSTRAINTS  Constraint analysis and design point for Concept 1
%  Builds the discipline bundle, evaluates every RFP constraint over a
%  wing-loading sweep, prints the design point, and draws the matching
%  diagram. Optionally runs the full sizing loop afterwards.
%
%  Needs on the path: the Concept1*.m and concept1_*.m files, the course
%  framework (get_con, get_state, get_miss_seg, AircraftState, the base
%  classes, MissionProfileReader, ttpa_requirements_path), and the JSON.

clear; clc; close all;

%% ----------------------------- Inputs ----------------------------------
W0_guess      = 9000;       % lbf, takeoff weight guess (only sets S_ref and P_SL)
WS_guess      = 20;         % lbf/ft^2, sets the initial S_ref -> CD0
WP_guess      = 9;          % lbf/hp, sets the initial P_SL
WS_sweep      = 10:0.25:50; % lbf/ft^2
b_max_ft      = 65;         % RFP wingspan limit
run_sizing    = false;      % true: also run concept1_sizing_loop

% Chosen design point (the red marker). The best point (blue marker) is the
% mathematical optimum: the feasible W/S with the highest W/P. A designer
% usually picks a point off the optimum to keep margin:
WS_design     = [];         % lbf/ft^2; [] = use the best point's W/S
WP_margin     = 0.95;       % chosen W/P = WP_margin * envelope W/P at WS_design
                            % (0.95 = 5 percent more installed power than the
                            % minimum; 1.0 = sit on the envelope). PLACEHOLDER

%% ---------------------------- Build and seed ----------------------------
obj = concept1_disciplines();
obj.geom.S_ref = W0_guess / WS_guess;   % drag polar reads S_wet / S_ref
obj.prop.P_SL  = W0_guess / WP_guess;

%% ------------------------------ Analysis --------------------------------
[WP_env, WS_wall, driving, ~, ~, d] = ...
    concept1_matching_envelope(WS_sweep, obj);

feas = d.feasible;                       % W/S <= wall and W/P > 0
have_pt = any(feas);

if have_pt
    % Best point: highest W/P on the feasible part of the envelope.
    WPf = WP_env;  WPf(~feas) = -Inf;
    [WP_best, jb] = max(WPf);
    WS_best = d.WS(jb);

    % Chosen design point.
    if isempty(WS_design)
        jc = jb;
    else
        [~, jc] = min(abs(d.WS - WS_design));
        if ~feas(jc)
            error('run_concept1_constraints:DesignPointInfeasible', ...
                ['WS_design = %.1f lbf/ft^2 is past the landing wall ', ...
                 '(%.1f lbf/ft^2) or outside the sweep.'], WS_design, WS_wall);
        end
    end
    WS_sel = d.WS(jc);
    WP_sel = WP_margin * WP_env(jc);
end

%% ------------------------------ Report ----------------------------------
fprintf('\n===== Concept 1 constraint analysis =====\n');
fprintf('Clean CD0 = %.4f, K = %.4f, (L/D)max = %.1f\n', ...
    obj.aero.CD0, obj.aero.K, obj.aero.LD_max);
fprintf('Landing wall (W/S max) : %.1f lbf/ft^2\n', WS_wall);
for k = find(~d.is_curve)
    fprintf('   %-45s %.1f lbf/ft^2\n', d.names(k), d.wall_each(k));
end

if ~have_pt
    fprintf('\nNo feasible design point on [%.1f, %.1f] lbf/ft^2.\n', ...
        WS_sweep(1), WS_sweep(end));
else
    fprintf('\nBEST POINT (optimum)\n');
    fprintf('  W/S = %.2f lbf/ft^2,  W/P = %.2f lbf/hp\n', WS_best, WP_best);
    fprintf('  Governing constraint: %s\n', driving(jb));

    fprintf('\nCHOSEN DESIGN POINT\n');
    fprintf('  W/S = %.2f lbf/ft^2,  W/P = %.2f lbf/hp\n', WS_sel, WP_sel);
    fprintf('  Governing constraint at this W/S: %s\n', driving(jc));

    S_dp = W0_guess / WS_sel;
    P_dp = W0_guess / WP_sel;
    b_dp = sqrt(obj.geom.AR * S_dp);
    fprintf('\nAt the guessed W0 = %.0f lbf:\n', W0_guess);
    fprintf('  S_ref = %.0f ft^2, installed reference power = %.0f hp\n', S_dp, P_dp);
    fprintf('  span  = %.1f ft  (RFP limit %.0f ft) -> %s\n', b_dp, b_max_ft, ...
        ternary(b_dp <= b_max_ft, 'OK', 'EXCEEDS LIMIT'));
    fprintf('(CD0 above was evaluated at the seeded S_ref; the sizing loop\n');
    fprintf(' iterates S_ref, W0 and P_SL until they agree.)\n\n');
end

%% -------------------------------- Plot ----------------------------------
figure('Color', 'w'); hold on; grid on; box on;

% Feasible region: under the envelope and left of the landing wall.
if have_pt
    xf = d.WS(feas);
    yf = WP_env(feas);
    fill([xf(1), xf, xf(end)], [0, yf, 0], [0.55 0.60 0.55], ...
        'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
        'DisplayName', 'Feasible region');
end

curve_ids = find(d.is_curve);
for k = curve_ids
    plot(d.WS, d.WP_all(k, :), 'LineWidth', 1.4, 'DisplayName', d.names(k));
end
plot(d.WS, WP_env, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Envelope');
xline(WS_wall, 'r--', 'LineWidth', 1.8, 'DisplayName', 'Landing wall');

if have_pt
    plot(WS_best, WP_best, 'o', 'MarkerSize', 12, 'MarkerFaceColor', 'b', ...
        'MarkerEdgeColor', 'k', 'DisplayName', ...
        sprintf('Best point (%.1f, %.2f)', WS_best, WP_best));
    plot(WS_sel, WP_sel, 'o', 'MarkerSize', 10, 'MarkerFaceColor', 'r', ...
        'MarkerEdgeColor', 'k', 'DisplayName', ...
        sprintf('Design point (%.1f, %.2f)', WS_sel, WP_sel));
    ylim([0, 2.2 * WP_best]);
end
xlabel('Wing loading (W/S)_{TO}  [lbf/ft^2]');
ylabel('Power loading (W/P)_{TO}  [lbf/hp]');
title('Concept 1 matching diagram (feasible: shaded, below the curves and left of the wall)');
legend('Location', 'northwest');

%% ------------------------- Optional sizing loop -------------------------
if run_sizing && have_pt
    opts = struct('W0', W0_guess, 'P0', W0_guess / WP_sel, ...
        'S0', W0_guess / WS_sel, 'WS_sweep', WS_sweep, ...
        'tol', 1e-3, 'max_iter', 60, 'relax', 0.5);
    [hist, converged, st] = concept1_sizing_loop(obj, opts);
    fprintf('Sizing converged: %d after %d passes\n', converged, st.n_iter);
    fprintf('W_TO = %.0f lbf, P_SL = %.0f hp, S_ref = %.0f ft^2\n', ...
        st.W0, st.P0, st.S0);
    fprintf('Final span = %.1f ft (limit %.0f ft)\n', ...
        obj.geom.b, b_max_ft);
    fprintf('Fuel %.0f lbf, battery %.0f lbf, OEW %.0f lbf\n', ...
        hist(end).W_fuel, hist(end).W_battery, hist(end).OEW);
end


function out = ternary(cond, a, b)
%TERNARY  Inline if for printing.
    if cond
        out = a;
    else
        out = b;
    end
end
