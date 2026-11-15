function [W_out, fuel_used, WF, info] = concept1_climb(W_in, obj, seg_no)
%CONCEPT1_CLIMB  Concept 1 turboprop mission climb on excess power.
%
%   Adapted from the professor's segment_climb_L2.m. The climb is split
%   into altitude bands; each band uses its midpoint atmosphere, computes
%   the speed for minimum power required, and integrates excess power and
%   turboprop fuel burn.
%
%   Concept 1 assumptions: both turboprops provide climb power at maximum
%   continuous rating; electric power is not credited. BSFC and propeller
%   efficiency are constant. The battery remains aboard at constant weight,
%   so only fuel burn reduces aircraft weight. Kinetic-energy changes as
%   climb speed varies are neglected, as in the professor's steady-climb
%   method.
%
%   Inputs
%     W_in   aircraft weight at climb start [lbf]
%     obj    discipline bundle with miss, geom, prop, and aero fields
%     seg_no mission segment index
%
%   Outputs
%     W_out     aircraft weight at climb end [lbf]
%     fuel_used fuel burned [lbf]
%     WF        climb weight fraction [-]
%     info      climb C_L, L/D, average speed, elapsed time, and band count

    seg   = get_miss_seg(seg_no, obj.miss);
    h_end = seg.alt;

    if seg_no > 1
        prev    = get_miss_seg(seg_no - 1, obj.miss);
        h_start = prev.alt;
    else
        h_start = 0;
    end

    if h_end <= h_start
        WF = 1;
        fuel_used = 0;
        W_out = W_in;
        info = struct('type', "climb", 'CL', NaN, 'LD', NaN, ...
            'V_fps', NaN, 'time_hr', 0, 'n_sub', 0);
        return;
    end

    n_sub = obj.miss.climb_segments;
    dh    = (h_end - h_start) / n_sub;  % ft per altitude band
    S     = obj.geom.S_ref;
    eta_p = obj.prop.prop_eff([], seg);
    C     = obj.prop.C_bhp([]);         % turboprop BSFC [lbm/(hp*hr)]
    polar = obj.aero.drag_polar([]);

    % Minimum-power-required lift coefficient for the clean parabolic polar.
    CL = sqrt(3 * polar.CD0 / polar.K1);
    CD = polar.CD0 + polar.K1 * CL^2;

    W = W_in;
    t_tot = 0;
    V_sum = 0;
    for i = 1:n_sub
        h       = h_start + (i - 0.5) * dh;
        state   = get_state(h);
        V       = sqrt(2 * (W / S) / (state.rho * CL));
        q       = 0.5 * state.rho * V^2;
        D       = q * S * CD;
        P_shaft = obj.prop.P_SL * ...
            obj.prop.power_lapse(state, "max_continuous");
        ROC     = (550 * eta_p * P_shaft - D * V) / W;

        if ~(isfinite(ROC) && ROC > 0)
            error('concept1_climb:CannotClimb', ...
                ['The aircraft cannot climb at %.0f ft: excess power is ', ...
                 'non-positive (P_shaft = %.1f hp, D = %.1f lbf). ', ...
                 'Check reference power, continuous rating, and aircraft weight.'], ...
                h, P_shaft, D);
        end

        dt    = dh / ROC;
        W     = W - C * P_shaft * (dt / 3600);
        t_tot = t_tot + dt;
        V_sum = V_sum + V;
    end

    WF        = W / W_in;
    fuel_used = (1 - WF) * W_in;
    W_out     = W_in * WF;

    info = struct('type', "climb", 'CL', CL, 'LD', CL/CD, ...
        'V_fps', V_sum/n_sub, 'time_hr', t_tot/3600, 'n_sub', n_sub);
end
