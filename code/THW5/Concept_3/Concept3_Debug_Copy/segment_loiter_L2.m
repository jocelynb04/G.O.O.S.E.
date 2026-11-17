function [W_out, fuel_used, WF, info] = segment_loiter_L2(W_in, obj, seg_no)
% Level-2 loiter: Breguet endurance at the loiter condition's own C_L.
%
% IHW1 used L/D = 0.866*L/D_max, the maximum-endurance rule of thumb for a
% propeller airplane. The loiter speed and altitude are given, so the lift
% coefficient is not a choice - it is pinned:
%
%   C_L = W / (q*S)
%   C_D = C_D0 + K1*C_L^2
%   WF  = exp( -E * V * c / (550 * eta_p * C_L/C_D) )
%
% [Breguet endurance, propeller: Raymer Eq. (6.15), p. 152, in ft/s with
% 550; the same relation as Roskam Part I Eq. (2.11), p. 15, in mph with
% 375.] E in hours, V in ft/s, c in lbm/(hp*hr).
%
% One piece is enough: the loiter burns little enough fuel that C_L hardly
% moves across it.

    % --- Milestone 1: the segment, its atmosphere, and the airplane ------
    seg   = get_miss_seg(seg_no, obj.miss);
    state = get_state(seg.alt);
    V     = seg.ktas*6076.115/3600;                               % ft/s
    q     = 0.5*state.rho*V^2;                               % lbf/ft^2
    S     = obj.geom.S_ref;
    eta_p = obj.prop.prop_eff(state,seg);
    C     = obj.prop.C_bhp(state);
    polar = obj.aero.drag_polar(state);

    % --- Milestone 2: the lift coefficient the loiter is flown at --------
    E  = seg.time_min/60;                                  % hr
    W = W_in;
    CL = W/(q*S);
    CD = polar.CD0 + polar.K1 * CL^2;
    LD = CL/CD;

    % --- Milestone 3: Breguet endurance ----------------------------------
    WF        = exp(-E*V*C/(550*eta_p*LD));
    fuel_used = (1-WF)*W_in;
    W_out     = W_in*WF;

    info = struct('type', "loiter", 'CL', CL, 'LD', LD, ...
                  'V_fps', V, 'time_hr', E, 'n_sub', 1);
end
