function [W_out, fuel_used, WF, info] = concept1_loiter_lift(W_in, obj, seg_no)
%CONCEPT1_LOITER_LIFT  Concept 1 loiter at its actual lift coefficient.
%
%   Adapted from the professor's segment_loiter_L2.m. It uses the loiter
%   condition's specified speed and altitude to calculate C_L rather than
%   assuming a fixed fraction of maximum lift-to-drag ratio.
%
%   Concept 1 assumptions: loiter is turboprop-only; C_bhp is the
%   turboprop's constant preliminary BSFC; prop_eff returns the loiter
%   propeller efficiency. The battery remains aboard at constant weight,
%   and only fuel burn reduces aircraft weight.
%
%   Inputs
%     W_in   aircraft weight at loiter start [lbf]
%     obj    discipline bundle with miss, geom, prop, and aero fields
%     seg_no mission segment index
%
%   Outputs
%     W_out     aircraft weight at loiter end [lbf]
%     fuel_used fuel burned [lbf]
%     WF        loiter weight fraction [-]
%     info      loiter C_L, L/D, speed, time, and piece count
%
%   One piece is retained from the professor's method: for this preliminary
%   model, loiter fuel burn is small enough that the starting-weight C_L is
%   representative of the segment.

    seg   = get_miss_seg(seg_no, obj.miss);
    state = get_state(seg.alt);

    V     = seg.ktas * 6076.115 / 3600;  % ft/s
    q     = 0.5 * state.rho * V^2;       % lbf/ft^2
    S     = obj.geom.S_ref;              % ft^2
    eta_p = obj.prop.prop_eff(state, seg);
    C     = obj.prop.C_bhp(state);       % turboprop BSFC [lbm/(hp*hr)]
    polar = obj.aero.drag_polar(state);

    E  = seg.time_min / 60;              % hr
    CL = W_in / (q * S);
    CD = polar.CD0 + polar.K1 * CL^2;
    LD = CL / CD;

    WF        = exp(-E * V * C / (LD * 550 * eta_p));
    fuel_used = (1 - WF) * W_in;
    W_out     = W_in * WF;

    info = struct('type', "loiter", 'CL', CL, 'LD', LD, ...
        'V_fps', V, 'time_hr', E, 'n_sub', 1);
end
