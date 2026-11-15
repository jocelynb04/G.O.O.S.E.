function row = concept1_sizing_pass(obj, W0, P0, S0, WS_sweep)
%CONCEPT1_SIZING_PASS  One Concept 1 sizing pass.
%
%   Preserves the professor's pass order: write the current aircraft state,
%   analyze constraints, size reference power and wing area, run the
%   mission, build OEW, then close takeoff weight. Mission energy is
%   W_energy = W_fuel + W_battery; battery weight is not included in OEW.
%
%   Inputs
%     obj       Concept 1 discipline bundle (mutated: P_SL, S_ref, W_energy)
%     W0        current takeoff-weight guess [lbf]
%     P0        current reference-power guess [hp]
%     S0        current wing-area guess [ft^2]
%     WS_sweep  wing-loading sweep [lbf/ft^2]
%
%   Output row contains this pass's design point, mission energy, weight
%   breakdown, closure, and residuals for the Step 12 sizing loop.

    obj.prop.P_SL = P0;
    obj.geom.S_ref = S0;

    [~, WS_wall, driving, WS, WP] = ...
        concept1_matching_envelope(WS_sweep, obj);
    if isnan(WS) || isnan(WP) || WS <= 0 || WP <= 0
        error('concept1_sizing_pass:NoFeasiblePoint', ...
            ['No feasible design point exists on the supplied wing-loading ', ...
             'sweep [%.2f, %.2f] lbf/ft^2. Check the constraint envelope ', ...
             'and its wing-loading wall (%.2f lbf/ft^2).'], ...
            WS_sweep(1), WS_sweep(end), WS_wall);
    end

    S_new = W0 / WS;
    P_new = W0 / WP;

    [fuel_burned, segment_weight, segment_wf, mission_detail, ...
        battery_energy_kWh, battery_energy_by_segment_kWh] = ...
        concept1_run_mission_L2(W0, obj);
    W_fuel = sum(fuel_burned);
    [W_battery, ~, W_energy] = obj.wts.energy_weights( ...
        battery_energy_kWh, W_fuel);
    fuel_fraction = W_fuel / W0;
    energy_fraction = W_energy / W0;

    obj.wts.W_TO = W0;
    bd = obj.wts.OEW_breakdown(W0);

    [W_new, denom] = Concept1_iteration.togw_update( ...
        obj.wts.payload(), bd.total, W_energy, W0);
    if isnan(W_new)
        error('concept1_sizing_pass:ClosureInfeasible', ...
            ['Takeoff-weight closure is infeasible at W0 = %.1f lbf: ', ...
             'denom = 1 - OEW/W0 - W_energy/W0 = %.4f must be > 0.'], ...
            W0, denom);
    end

    j_best = find(reshape(WS_sweep, 1, []) == WS, 1);
    if isempty(j_best)
        driving_best = "";
    else
        driving_best = driving(j_best);
    end

    row.iter = NaN; % Step 12 assigns the actual iteration index.
    row.W_TO = W0;
    row.P_SL = P0;
    row.S_ref = S0;
    row.WS = WS;
    row.WP = WP;
    row.WS_wall = WS_wall;
    row.driving = driving_best;
    row.W_fuel = W_fuel;
    row.W_battery = W_battery;
    row.W_energy = W_energy;
    row.fuel_fraction = fuel_fraction;
    row.energy_fraction = energy_fraction;
    row.battery_energy_kWh = battery_energy_kWh;
    row.battery_energy_by_segment_kWh = battery_energy_by_segment_kWh;
    row.fuel_burned = fuel_burned;
    row.segment_weight = segment_weight;
    row.segment_wf = segment_wf;
    row.mission_detail = mission_detail;
    row.OEW_breakdown = bd;
    row.OEW = bd.total;
    row.W_payload = obj.wts.payload();
    row.denom = denom;
    row.W_TO_new = W_new;
    row.P_SL_new = P_new;
    row.S_ref_new = S_new;
    row.res_W = abs(W_new - W0) / W_new;
    row.res_P = abs(P_new - P0) / P_new;
    row.res_S = abs(S_new - S0) / S_new;
end
