
function [W_out, fuel_used, WF, info] = segment_loiter_L2(W_in, obj, seg_no)
% Level-2 loiter: Breguet endurance at the actual lift coefficient.

    % --- Milestone 1: Segment, atmosphere, and airplane ---
    seg = get_miss_seg(seg_no, obj.miss);
    state = get_state(seg.alt);

    V = seg.ktas * 6076.115 / 3600;   % ft/s
    q = 0.5 * state.rho * V^2;         % lbf/ft^2
    S = obj.geom.S_ref;                % ft^2

    eta_p = obj.prop.prop_eff(state, seg);
    C = obj.prop.C_bhp(state);
    polar = obj.aero.drag_polar(state);

    % --- Milestone 2: Actual lift and drag coefficients ---
    E = seg.time_min / 60;             % hours

    CL = W_in / (q * S);
    CD = polar.CD0 + polar.K1 * CL^2;
    LD = CL / CD;

    % --- Milestone 3: Breguet endurance ---
    WF = exp(-E * V * C / (550 * eta_p * LD));

    fuel_used = (1 - WF) * W_in;
    W_out = W_in * WF;

    info = struct('type', "loiter", 'CL', CL, 'LD', LD, ...
                  'V_fps', V, 'time_hr', E, 'n_sub', 1);
end
