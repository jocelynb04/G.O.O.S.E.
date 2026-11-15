function [W_out, fuel_used, WF, info] = concept1_cruise_lift(W_in, obj, seg_no)
% Concept 1 cruise at its actual lift coefficient.
%
%   Adapted from the professor's segment_cruise_L2.m. The original
%   sub-segment structure and Breguet weight update are retained.
%
%   Concept 1 assumption: cruise is turboprop-only. Therefore obj.prop.C_bhp
%   and obj.prop.prop_eff must return the turboprop cruise fuel consumption
%   and shared propeller efficiency. Electric power is not credited in this
%   segment. W_in is the aircraft weight at the segment start, including any
%   battery carried aboard; only fuel burn reduces the aircraft weight.
%
%   Inputs
%     W_in  aircraft weight at the segment start [lbf]
%     obj   discipline bundle with miss, geom, prop, and aero fields
%     seg_no mission segment index
%
%   Outputs
%     W_out    aircraft weight at segment end [lbf]
%     fuel_used fuel burned [lbf]
%     WF       segment weight fraction [-]
%     info     average CL and L/D, speed, time, and sub-segment count

    seg   = get_miss_seg(seg_no, obj.miss);
    state = get_state(seg.alt);

    V     = seg.ktas * 6076.115 / 3600;      % ft/s
    q     = 0.5 * state.rho * V^2;           % lbf/ft^2
    S     = obj.geom.S_ref;                  % ft^2
    eta_p = obj.prop.prop_eff(state, seg);
    C     = obj.prop.C_bhp(state);           % turboprop BSFC [lbm/(hp*hr)]
    polar = obj.aero.drag_polar(state);

    n_sub = obj.miss.cruise_segments;
    dR_mi = seg.dist * 1.15077945 / n_sub;   % nmi -> statute mi per piece

    W      = W_in;
    CL_sum = 0;
    LD_sum = 0;
    for i = 1:n_sub
        CL = W / (q * S);
        CD = polar.CD0 + polar.K1 * CL^2;
        LD = CL / CD;
        W  = W * exp(-dR_mi * C / (375 * eta_p * LD));
        CL_sum = CL_sum + CL;
        LD_sum = LD_sum + LD;
    end

    WF        = W / W_in;
    fuel_used = (1 - WF) * W_in;
    W_out     = W_in * WF;

    if WF^(1/n_sub) < 0.9
        warning('concept1_cruise_lift:SegmentTooCoarse', ...
            ['A cruise sub-segment weight fraction is %.3f, below the 0.9 ', ...
             'accuracy floor. Increase missions.std_mission.cruise_segments.'], ...
            WF^(1/n_sub));
    end

    info = struct('type', "cruise", 'CL', CL_sum/n_sub, ...
        'LD', LD_sum/n_sub, 'V_fps', V, ...
        'time_hr', seg.dist*6076.115/V/3600, 'n_sub', n_sub);
end
