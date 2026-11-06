function [W_out, fuel_used, WF, info] = segment_cruise_L2(W_in, obj, seg_no)
% Level-2 Breguet cruise at actual C_L, with updated drag/propulsion.
% Caravan adaptation: speed, route and altitude must be changed in JSON;
% 159 KTAS maximum and 875 nmi maximum range are NOT simultaneous claims.
    seg = get_miss_seg(seg_no, obj.miss);
    state = get_state(seg.alt);
    V = seg.ktas * 6076.115 / 3600;
    q = 0.5 * state.rho * V^2;
    S = obj.geom.S_ref;
    eta_p = obj.prop.prop_eff(state, seg);
    C = obj.prop.C_bhp(state);
    polar = obj.aero.drag_polar(state);
    n_sub = obj.miss.cruise_segments;
    dR_mi = seg.dist * 1.15077945 / n_sub;
    W = W_in;
    CL_sum = 0;
    LD_sum = 0;
    for i = 1:n_sub
        CL = W / (q * S);
        CD = polar.CD0 + polar.K1 * CL^2;
        LD = CL / CD;
        W = W * exp(-dR_mi * C / (375 * eta_p * LD));
        CL_sum = CL_sum + CL;
        LD_sum = LD_sum + LD;
    end
    WF = W / W_in;
    fuel_used = (1 - WF) * W_in;
    W_out = W_in * WF;
    if WF^(1/n_sub) < 0.9
        warning('segment_cruise_L2:SegmentTooCoarse', ...
            ['A cruise sub-segment weight fraction is %.3f, below the 0.9 ', ...
             'accuracy floor. Increase missions.std_mission.cruise_segments.'], ...
            WF^(1/n_sub));
    end
    info = struct('type', "cruise", 'CL', CL_sum/n_sub, 'LD', LD_sum/n_sub, ...
                  'V_fps', V, 'time_hr', seg.dist*6076.115/V/3600, 'n_sub', n_sub);
end
