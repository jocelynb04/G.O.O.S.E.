
function [W_out, fuel_used, WF, info] = segment_climb_L2(W_in, obj, seg_no)
% Level-2 climb: flown on excess power, fuel burned at climb power.
%
% The altitude change is divided into n_sub bands.
% Each band is evaluated at its midpoint.

    seg = get_miss_seg(seg_no, obj.miss);
    h_end = seg.alt;

    % --- Milestone 1: Starting altitude ---
    if seg_no == 1
        h_start = 0;
    else
        previous_seg = get_miss_seg(seg_no - 1, obj.miss);
        h_start = previous_seg.alt;
    end

    if h_end <= h_start
        WF = 1;
        fuel_used = 0;
        W_out = W_in;

        info = struct('type', "climb", 'CL', NaN, 'LD', NaN, ...
                      'V_fps', NaN, 'time_hr', 0, 'n_sub', 0);
        return;
    end

    % --- Milestone 2: Altitude bands and aircraft ---
    n_sub = obj.miss.climb_segments;
    dh = (h_end - h_start) / n_sub;

    S = obj.geom.S_ref;
    eta_p = obj.prop.prop_eff([], seg);
    C = obj.prop.C_bhp([]);
    polar = obj.aero.drag_polar([]);

    % --- Milestone 3: Minimum-power lift coefficient ---
    CL = sqrt(3 * polar.CD0 / polar.K1);
    CD = polar.CD0 + polar.K1 * CL^2;

    W = W_in;
    t_tot = 0;
    V_sum = 0;

    for i = 1:n_sub

        % --- Milestone 4: Evaluate each altitude band ---
        h = h_start + (i - 0.5) * dh;

        state = get_state(h);

        V = sqrt(2 * (W / S) / (state.rho * CL));

        q = 0.5 * state.rho * V^2;

        D = q * S * CD;

        P_shaft = obj.prop.P_SL * ...
            obj.prop.power_lapse(state, "max_continuous");

        ROC = (550 * eta_p * P_shaft - D * V) / W;

        % Check that the aircraft can climb
        if ~(isfinite(ROC) && ROC > 0)
            error('segment_climb_L2:CannotClimb', ...
                ['The airplane cannot climb at %.0f ft: excess power is ', ...
                 'non-positive (P_shaft = %.1f hp, D = %.1f lbf). The engine ', ...
                 'is too small for this weight.'], h, P_shaft, D);
        end

        % --- Milestone 5: Time and fuel consumption ---
        dt = dh / ROC;

        W = W - C * P_shaft * dt / 3600;

        t_tot = t_tot + dt;
        V_sum = V_sum + V;

    end

    % --- Final weight fraction and fuel used ---
    WF = W / W_in;

    fuel_used = (1 - WF) * W_in;

    W_out = W_in * WF;

    info = struct('type', "climb", ...
                  'CL', CL, ...
                  'LD', CL/CD, ...
                  'V_fps', V_sum/n_sub, ...
                  'time_hr', t_tot/3600, ...
                  'n_sub', n_sub);
end
