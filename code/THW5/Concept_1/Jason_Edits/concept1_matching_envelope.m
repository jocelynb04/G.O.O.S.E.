function [WP_env, WS_wall, driving, WS_dp, WP_dp, detail] = ...
        concept1_matching_envelope(WS_sweep, obj)
%CONCEPT1_MATCHING_ENVELOPE  Combine the constraints and pick the design point.
%
%   [WP_env, WS_wall, driving, WS_dp, WP_dp, detail] = ...
%       concept1_matching_envelope(WS_sweep, obj)
%
%   This is the function concept1_sizing_pass calls:
%       [~, WS_wall, driving, WS, WP] = concept1_matching_envelope(WS_sweep, obj);
%
%   Inputs
%     WS_sweep  wing-loading sweep [lbf/ft^2]
%     obj       Concept 1 discipline bundle; obj.cons holds the conditions
%               (see concept1_rfp_constraints) and obj.geom.S_ref must be
%               set, because the drag polar, and so every curve, reads it.
%   Outputs
%     WP_env    envelope: largest feasible (W/P)_TO at each WS [lbf/hp]
%     WS_wall   largest allowed (W/S)_TO, from the landing conditions
%     driving   string row; name of the constraint that sets WP_env at each WS
%     WS_dp     design-point wing loading (an element of WS_sweep) [lbf/ft^2]
%     WP_dp     design-point power loading [lbf/hp]
%     detail    struct with every constraint curve, for plotting
%
%   CONDITION TYPES (obj.cons(k).type) and what they produce:
%     cruise_speed   W/P curve   concept1_constraint_cruise_speed
%     climb_rate     W/P curve   concept1_constraint_climb
%     water_takeoff  W/P curve   concept1_constraint_takeoff
%     water_landing  W/S wall    concept1_constraint_landing
%     land_landing   W/S wall    concept1_constraint_landing
%
%   DESIGN POINT. Feasible means W/S <= WS_wall and every constraint
%   satisfied. Among feasible wing loadings the design point has the
%   highest W/P (least installed power per unit weight). A wing loading
%   within 0.5 percent of that best W/P is accepted, and the highest such
%   W/S is taken, which gives the smaller wing at negligible power cost.
%   Where nothing is feasible, WS_dp and WP_dp are NaN, which
%   concept1_sizing_pass reports as NoFeasiblePoint.

    tol = 0.005;

    WS = reshape(WS_sweep, 1, []);
    nC = numel(obj.cons);

    names     = strings(1, nC);
    is_curve  = false(1, nC);
    WP_all    = nan(nC, numel(WS));
    wall_each = inf(1, nC);

    for k = 1:nC
        con = get_con(k, obj.cons);
        names(k) = con.name;

        ctype = char(con.type);
        if strcmp(ctype, 'cruise_speed')
            WP_all(k, :) = concept1_constraint_cruise_speed(WS, obj, k);
            is_curve(k) = true;
        elseif strcmp(ctype, 'climb_rate')
            WP_all(k, :) = concept1_constraint_climb(WS, obj, k);
            is_curve(k) = true;
        elseif strcmp(ctype, 'water_takeoff')
            WP_all(k, :) = concept1_constraint_takeoff(WS, obj, k);
            is_curve(k) = true;
        elseif strcmp(ctype, 'water_landing') || strcmp(ctype, 'land_landing')
            wall_each(k) = concept1_constraint_landing(obj, k);
        else
            error('concept1_matching_envelope:UnknownConditionType', ...
                'Condition %d has type "%s", which the Concept 1 envelope does not handle.', ...
                k, ctype);
        end
    end

    if ~any(is_curve)
        error('concept1_matching_envelope:NoPowerConstraints', ...
            'obj.cons contains no W/P constraints.');
    end

    curves = WP_all(is_curve, :);
    if any(isnan(curves(:)))
        error('concept1_matching_envelope:NaNConstraint', ...
            'A constraint returned NaN; check the discipline inputs.');
    end

    [WP_env, idx] = min(curves, [], 1);
    curve_ids = find(is_curve);
    driving   = names(curve_ids(idx));

    WS_wall = min(wall_each);

    feasible = (WS <= WS_wall) & (WP_env > 0);
    if ~any(feasible)
        WS_dp = NaN;
        WP_dp = NaN;
    else
        WPf = WP_env;
        WPf(~feasible) = -Inf;
        WP_best = max(WPf);
        j = find(WPf >= (1 - tol) * WP_best, 1, 'last');
        WS_dp = WS(j);
        WP_dp = WP_env(j);
    end

    detail = struct('WS', WS, 'names', names, 'is_curve', is_curve, ...
        'WP_all', WP_all, 'wall_each', wall_each, 'WS_wall', WS_wall, ...
        'feasible', feasible);
end
