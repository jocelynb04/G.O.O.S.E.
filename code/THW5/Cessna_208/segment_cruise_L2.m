
function [W_out, fuel_used, WF, info] = segment_cruise_L2(W_in, obj, seg_no)
% Level-2 cruise: Breguet range, flown at the lift coefficient the airplane
% actually has, recomputed as fuel burns off.
%
% The cruise is split into n_sub pieces and each piece uses its own C_L:
%
%   C_L = W / (q*S)
%   C_D = C_D0 + K1*C_L^2
%   W = W * exp(-dR*C/(375*eta_p*(C_L/C_D)))

    % --- Milestone 1: Segment, atmosphere, and airplane ---
    seg = get_miss_seg(seg_no, obj.miss);
    state = get_state(seg.alt);

    V = seg.ktas * 6076.115 / 3600;   % ft/s
    q = 0.5 * state.rho * V^2;        % lbf/ft^2
    S = obj.geom.S_ref;               % Wing area [ft^2]

    eta_p = obj.prop.prop_eff(state, seg);
    C = obj.prop.C_bhp(state);
    polar = obj.aero.drag_polar(state);

    % --- Milestone 2: Split cruise into sub-segments ---
    n_sub = obj.miss.cruise_segments;
    dR_mi = seg.dist * 1.15077945 / n_sub;

    % --- Milestone 3: Calculate lift, drag, and fuel burn ---
    W = W_in;
    CL_sum = 0;
    LD_sum = 0;

    for i = 1:n_sub

        CL = W / (q*S);

        CD = polar.CD0 + polar.K1 * CL^2;

        LD = CL / CD;

        W = W * exp(-dR_mi * C / (375 * eta_p * LD));

        CL_sum = CL_sum + CL;
        LD_sum = LD_sum + LD;

    end

    % --- Milestone 4: Weight fraction and fuel used ---
    WF = W / W_in;

    fuel_used = (1 - WF) * W_in;

    W_out = W_in * WF;

    % Check sub-segment accuracy
    if WF^(1/n_sub) < 0.9
        warning('segment_cruise_L2:SegmentTooCoarse', ...
            ['A cruise sub-segment weight fraction is %.3f, below the 0.9 ', ...
             'accuracy floor. Increase missions.std_mission.cruise_segments.'], ...
            WF^(1/n_sub));
    end

    % Store cruise information
    info = struct('type', "cruise", ...
                  'CL', CL_sum/n_sub, ...
                  'LD', LD_sum/n_sub, ...
                  'V_fps', V, ...
                  'time_hr', seg.dist*6076.115/V/3600, ...
                  'n_sub', n_sub);

end
