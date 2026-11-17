function [WS_max, extra] = concept1_constraint_landing(obj, con_no)
%CONCEPT1_CONSTRAINT_LANDING  Landing distance sets a maximum wing loading.
%
%   [WS_max, extra] = concept1_constraint_landing(obj, con_no)
%
%   Landing distance does not depend on installed power, so this condition
%   is a vertical wall in the W/S - W/P plane rather than a W/P curve.
%
%   Inputs
%     obj     Concept 1 discipline bundle
%     con_no  condition index; the condition carries distance_ft (required
%             distance from a 50 ft obstacle to a stop) and mu (average
%             deceleration coefficient: water drag or wheel braking)
%   Outputs
%     WS_max  largest (W/S)_TO whose landing distance is within the limit
%             [lbf/ft^2]
%     extra   struct with the stall speed at the wall and assumptions
%
%   METHOD (Raymer-style landing build-up, solved for the stall speed):
%
%     approach         3 deg glide path to the obstacle
%     flare            V_F = 1.23 V_stall, circular arc, R = V_F^2 / (0.2 g)
%     air distance     (h_obs - h_f)/tan(3 deg) + R sin(3 deg)
%     touchdown        V_TD = 1.15 V_stall
%     free roll        t_free seconds at V_TD
%     deceleration     V_TD^2 / (2 g mu)
%
%   The total is increasing in V_stall, so the V_stall that meets the
%   distance exactly is found by bisection, then
%
%       (W/S) = 0.5 rho V_stall^2 CLmax_landing / beta
%
%   WATER. The water deceleration mu = 0.15 is a PLACEHOLDER that stands
%   in for hull drag; no spray or hydrodynamic model is included. This
%   wall is very sensitive to it, so replace it with towing-tank data.

    con   = get_con(con_no, obj.cons);
    raw   = obj.cons(con_no);
    state = get_state(con.alt);

    if isempty(con.distance_ft)
        error('concept1_constraint_landing:MissingDistance', ...
            'Condition %d carries no distance_ft.', con_no);
    end

    cfg = obj.aero.get_config_polar(state, con);

    g      = 32.174;
    mu     = 0.15;
    if isfield(raw, 'mu') && ~isempty(raw.mu) && raw.mu > 0
        mu = raw.mu;
    end
    h_obs  = 50;                    % ft
    gam    = 3 * pi / 180;          % approach glide angle [rad]
    t_free = 2.0;                   % s, free roll before deceleration
    s_req  = con.distance_ft;

    lo = 20;                        % ft/s
    hi = 250;                       % ft/s
    for it = 1:80
        mid = 0.5 * (lo + hi);
        if landing_distance(mid, g, mu, h_obs, gam, t_free) <= s_req
            lo = mid;
        else
            hi = mid;
        end
    end
    Vs = lo;

    WS_max = 0.5 * state.rho * Vs^2 * cfg.CLmax / con.beta;

    extra = struct('method', "50 ft obstacle landing build-up", ...
        'V_stall_fps', Vs, 'V_stall_kt', Vs * 3600 / 6076.115, ...
        'mu', mu, 'CLmax', cfg.CLmax);
end


function s = landing_distance(Vs, g, mu, h_obs, gam, t_free)
%LANDING_DISTANCE  Obstacle-to-stop distance for a stall speed [ft].
    V_F  = 1.23 * Vs;
    R    = V_F^2 / (0.2 * g);
    h_f  = R * (1 - cos(gam));
    s_a  = (h_obs - h_f) / tan(gam);
    s_f  = R * sin(gam);
    V_TD = 1.15 * Vs;
    s_g  = V_TD^2 / (2 * g * mu) + t_free * V_TD;
    s    = s_a + s_f + s_g;
end
