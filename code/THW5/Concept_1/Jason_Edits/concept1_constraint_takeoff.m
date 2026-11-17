function [WP_max, extra] = concept1_constraint_takeoff(WS, obj, con_no)
%CONCEPT1_CONSTRAINT_TAKEOFF  Takeoff distance over a 50 ft obstacle.
%
%   [WP_max, extra] = concept1_constraint_takeoff(WS, obj, con_no)
%
%   Inputs
%     WS      takeoff wing loading (W/S)_TO [lbf/ft^2], scalar or row vector
%     obj     Concept 1 discipline bundle
%     con_no  condition index; the condition carries distance_ft (required
%             distance to clear 50 ft) and mu (resistance coefficient)
%   Outputs
%     WP_max  largest (W/P)_TO that meets the distance [lbf/hp]; 0 where no
%             realistic power meets it
%     extra   struct describing the method and its assumptions
%
%   POWER IS ELECTRIC. The RFP forbids tailpipe emissions in takeoff, so
%   the available power is the electric rating, P_electric_SL, through
%   power_ratio with propulsion_mode = "electric".
%
%   METHOD (Raymer-style energy/segment build-up, solved for W/P):
%
%   1. Ground (or water) run, constant average acceleration evaluated at
%      0.7 V_LOF:
%
%         a/g = T/W - D/W - mu (1 - L/W)       s_G = V_LOF^2 / (2 g a/g)
%
%      T/W = 550 eta_p kP / ( beta (W/P) V )  is propeller thrust at the
%      average speed. D/W and L/W use the takeoff-flap polar, with the lift
%      coefficient at the hull's planing attitude taken as CLmax / k_LOF^2
%      (lift equals weight at liftoff).
%
%   2. Transition at V_TR = 1.15 V_stall along a circular arc, then a
%      straight climb to the obstacle, with the climb angle from the
%      excess thrust sin(gamma) = T/W - D/W at V_TR.
%
%   The total s_G + s_transition + s_climb is increasing in W/P, so each
%   wing loading is solved by bisection for the W/P that meets exactly the
%   required distance.
%
%   WATER. Hydrodynamic resistance (hump drag, spray) is NOT modeled by the
%   aerodynamic polar. It enters only through mu, a lumped average
%   resistance-to-weight coefficient. Treat mu as a placeholder until the
%   towing-tank data the RFP requires is available.

    con   = get_con(con_no, obj.cons);
    raw   = obj.cons(con_no);
    state = get_state(con.alt);

    if isempty(con.distance_ft)
        error('concept1_constraint_takeoff:MissingDistance', ...
            'Condition %d carries no distance_ft.', con_no);
    end

    con.propulsion_mode = "electric";
    kP    = obj.prop.power_ratio(state, con);
    if ~isfinite(kP) || kP <= 0
        error('concept1_constraint_takeoff:InvalidPowerRatio', ...
            'Takeoff electric power ratio must be positive and finite.');
    end
    eta_p = obj.prop.prop_eff(state, struct('type', "takeoff"));
    cfg   = obj.aero.get_config_polar(state, con);

    p.rho   = state.rho;
    p.g     = 32.174;
    p.beta  = con.beta;
    p.kP    = kP;
    p.eta_p = eta_p;
    p.CD0   = cfg.CD0;
    p.K1    = cfg.K1;
    p.CLmax = cfg.CLmax;
    p.mu    = 0.10;
    if isfield(raw, 'mu') && ~isempty(raw.mu) && raw.mu > 0
        p.mu = raw.mu;
    end
    p.k_LOF = 1.10;                 % V_LOF / V_stall
    p.k_TR  = 1.15;                 % V_TR  / V_stall
    p.h_obs = 50;                   % obstacle height [ft]
    p.s_req = con.distance_ft;

    WP_max = zeros(size(WS));
    for j = 1:numel(WS)
        WP_max(j) = solve_WP(WS(j), p);
    end

    extra = struct('method', "ground run + transition + climb", ...
        'mu', p.mu, 'kP', kP, 'eta_p', eta_p, 'CLmax', p.CLmax);
end


function WP = solve_WP(WS, p)
%SOLVE_WP  Largest W/P with takeoff distance <= required, by bisection.
    lo = 0.5;                       % lbf/hp, very high power
    hi = 100;                       % lbf/hp, very low power
    if takeoff_distance(lo, WS, p) > p.s_req
        WP = 0;                     % not achievable at any realistic power
        return;
    end
    for it = 1:60
        mid = 0.5 * (lo + hi);
        if takeoff_distance(mid, WS, p) <= p.s_req
            lo = mid;
        else
            hi = mid;
        end
    end
    WP = lo;
end


function s = takeoff_distance(WP, WS, p)
%TAKEOFF_DISTANCE  Total distance to clear the obstacle [ft]; Inf if it cannot.
    Vs    = sqrt(2 * p.beta * WS / (p.rho * p.CLmax));
    V_LOF = p.k_LOF * Vs;

    % --- run, average conditions at 0.7 V_LOF ---
    Vb  = 0.7 * V_LOF;
    qb  = 0.5 * p.rho * Vb^2;
    CLg = p.CLmax / p.k_LOF^2;
    CDg = p.CD0 + p.K1 * CLg^2;
    DW  = qb * CDg / (p.beta * WS);
    LW  = qb * CLg / (p.beta * WS);
    TWb = 550 * p.eta_p * p.kP / (p.beta * WP * Vb);
    acc = TWb - DW - p.mu * (1 - LW);          % a/g
    if acc <= 0
        s = Inf;
        return;
    end
    sG = V_LOF^2 / (2 * p.g * acc);

    % --- transition and climb to the obstacle ---
    Vtr  = p.k_TR * Vs;
    qtr  = 0.5 * p.rho * Vtr^2;
    CLtr = p.beta * WS / qtr;
    CDtr = p.CD0 + p.K1 * CLtr^2;
    TWtr = 550 * p.eta_p * p.kP / (p.beta * WP * Vtr);
    sing = TWtr - CDtr / CLtr;                 % sin(climb angle)
    if sing <= 1e-3
        s = Inf;
        return;
    end
    gam = asin(min(sing, 0.99));
    R   = Vtr^2 / (0.2 * p.g);                 % transition radius
    h_tr = R * (1 - cos(gam));
    if h_tr < p.h_obs
        s_air = R * sin(gam) + (p.h_obs - h_tr) / tan(gam);
    else
        s_air = sqrt(2 * R * p.h_obs - p.h_obs^2);
    end

    s = sG + s_air;
end
