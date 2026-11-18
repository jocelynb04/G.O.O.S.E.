function result = concept1_output_design_point()
%CONCEPT1_OUTPUT_DESIGN_POINT Compute and plot the Concept 1 constraint point.
%
% Run this function in MATLAB from the generated project files. It builds
% the Concept 1 discipline objects, runs the constraint set, prints the
% theoretical minimum-reference-power point, and plots the matching chart.
%
% IMPORTANT: the current takeoff and landing constraints are runway
% correlations. The printed point is therefore a preliminary proxy for a
% water aircraft, not a validated water takeoff/landing design point.

    output_dir = fileparts(mfilename('fullpath'));
    project_dir = fileparts(output_dir);
    framework_candidates = { ...
        fullfile(project_dir, 'work', 'ihw3_solution', 'IHW3_Solution'), ...
        fullfile(getenv('USERPROFILE'), 'Documents', 'Codex', ...
            '2026-11-04', 'i-a', 'work', 'ihw3_solution', 'IHW3_Solution')};
    helper_candidates = {output_dir, ...
        fullfile(getenv('USERPROFILE'), 'Documents', 'Codex', ...
            '2026-11-04', 'i-a', 'outputs')};
    framework_dir = '';
    for k = 1:numel(framework_candidates)
        if isfolder(framework_candidates{k})
            framework_dir = framework_candidates{k};
            break;
        end
    end
    concept1_dir = ...
        'C:\Users\Josep\OneDrive\Documents\Fall 2026\Senior Design\Homework\THW5';
    json_path = fullfile(output_dir, 'Concept1_requirements_template.json');

    if isempty(framework_dir)
        error('concept1_output_design_point:FrameworkNotFound', ...
            ['Could not find the extracted IHW3_Solution framework. ', ...
             'Update framework_candidates near the top of this function ', ...
             'to point to the folder containing constraint_takeoff.m.']);
    end

    helper_dir = '';
    for k = 1:numel(helper_candidates)
        if isfile(fullfile(helper_candidates{k}, ...
                'concept1_run_constraints.m')) && ...
                isfile(fullfile(helper_candidates{k}, ...
                'concept1_matching_envelope.m'))
            helper_dir = helper_candidates{k};
            break;
        end
    end
    if isempty(helper_dir)
        error('concept1_output_design_point:HelpersNotFound', ...
            ['Could not find concept1_run_constraints.m and ', ...
             'concept1_matching_envelope.m. Keep the Concept 1 helper ', ...
             'files together in the outputs folder.']);
    end

    required_paths = {framework_dir, helper_dir, concept1_dir, json_path};
    for k = 1:numel(required_paths)
        if ~isfolder(required_paths{k}) && ~isfile(required_paths{k})
            error('concept1_output_design_point:MissingPath', ...
                'Required project path does not exist: %s', required_paths{k});
        end
    end

    addpath(framework_dir, helper_dir, concept1_dir, output_dir);
    J = jsondecode(fileread(json_path));

    % Build Concept 1 objects in their dependency order.
    prop = Concept1HybridProp(json_path);
    geom = Concept1Geom(json_path, prop);
    aero = Concept1Aero(json_path, geom);
    cons = ConstraintSetImporter.read_conditions(string(json_path));
    obj = struct('prop', prop, 'geom', geom, 'aero', aero, 'cons', cons);

    % Drag-based cruise needs a current wing geometry. This is only the
    % initial geometry for this first matching-chart pass; the sizing loop
    % updates S_ref and repeats the constraint analysis as weight converges.
    obj.geom.S_ref = J.sizing.S_ref_guess_ft2;

    % P_SL is a reference for normalizing W/P. The ratio is initialized
    % from the starter value but does not determine the resulting W/P curve.
    obj.prop.P_SL = J.sizing.W_TO_guess_lbf / ...
        J.constraints.design_point.power_loading_lb_per_hp;

    C = J.constraints;
    WS = linspace(C.wing_loading_range_psf(1), ...
        C.wing_loading_range_psf(2), C.wing_loading_points);

    % Include the exact wing-loading wall in the sweep if it falls in range.
    [~, walls] = concept1_run_constraints(WS, obj);
    finite_walls = walls(isfinite(walls));
    if ~isempty(finite_walls)
        WS_wall = min(finite_walls);
        if WS_wall >= min(WS) && WS_wall <= max(WS)
            WS = unique([WS, WS_wall]);
        end
    end

    [WP_limits, WS_walls, names, types] = concept1_run_constraints(WS, obj);
    [WP_envelope, WS_max, driving, WS_design, WP_design] = ...
        concept1_matching_envelope(WS, obj);

    if ~isfinite(WS_design) || ~isfinite(WP_design)
        error('concept1_output_design_point:NoFeasiblePoint', ...
            'No feasible design point was found on the configured wing-loading sweep.');
    end

    W_TO_guess = J.sizing.W_TO_guess_lbf;
    S_design = W_TO_guess / WS_design;
    P_reference = W_TO_guess / WP_design;

    fprintf('\nCONCEPT 1 CONSTRAINT ANALYSIS (PRELIMINARY)\n');
    fprintf('Constraint analysis geometry S_ref: %.2f ft^2\n', obj.geom.S_ref);
    fprintf('Maximum wing loading from current constraints: %.2f lbf/ft^2\n', WS_max);
    fprintf('Theoretical design point W/S: %.2f lbf/ft^2\n', WS_design);
    fprintf('Theoretical design point W/P: %.2f lbf/hp\n', WP_design);
    fprintf('Driving constraint at that point: %s\n', driving(WS == WS_design));
    fprintf('At the %.0f lbf starting weight: S_ref = %.2f ft^2; P_SL reference = %.1f hp\n', ...
        W_TO_guess, S_design, P_reference);
    fprintf(['Caution: takeoff and landing use runway correlations, so this is ', ...
        'not a validated water-performance design point.\n\n']);

    % Print the power-loading limit contributed by each condition.
    fprintf('CONSTRAINTS\n');
    for k = 1:numel(names)
        vals = WP_limits(k, :);
        vals = vals(isfinite(vals));
        if isempty(vals)
            wall = WS_walls(k);
            fprintf('  %-18s %-16s wing-loading limit = %.2f lbf/ft^2\n', ...
                names(k), types(k), wall);
        else
            fprintf('  %-18s %-16s max W/P in sweep = %.2f lbf/hp\n', ...
                names(k), types(k), max(vals));
        end
    end

    figure('Name', 'Concept 1 Constraint Matching Chart', 'Color', 'w');
    hold on;
    grid on;
    for k = 1:numel(names)
        if any(isfinite(WP_limits(k, :)))
            plot(WS, WP_limits(k, :), 'LineWidth', 1.1, ...
                'DisplayName', char(names(k)));
        end
    end
    plot(WS, WP_envelope, 'k-', 'LineWidth', 2.2, ...
        'DisplayName', 'Feasible power-loading envelope');
    if isfinite(WS_max)
        xline(WS_max, 'r--', 'LineWidth', 1.5, ...
            'DisplayName', 'Maximum wing loading');
    end
    plot(WS_design, WP_design, 'ko', 'MarkerFaceColor', 'y', ...
        'MarkerSize', 8, 'DisplayName', 'Theoretical design point');
    xlabel('Wing loading, W/S (lbf/ft^2)');
    ylabel('Power loading, W/P (lbf/hp)');
    title({'Concept 1 preliminary matching chart', ...
        'Runway takeoff/landing proxies; water performance not modeled'});
    legend('Location', 'best');
    hold off;

    result = struct('WS_design_psf', WS_design, ...
        'WP_design_lb_per_hp', WP_design, 'WS_max_psf', WS_max, ...
        'driving_constraint', driving(WS == WS_design), ...
        'W_TO_guess_lbf', W_TO_guess, 'S_ref_at_guess_ft2', S_design, ...
        'P_SL_reference_hp', P_reference, 'wing_loading_sweep_psf', WS, ...
        'WP_limits_lb_per_hp', WP_limits, 'constraint_names', names, ...
        'constraint_types', types, 'runway_proxy_warning', true);
end
