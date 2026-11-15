function [WP_max, extra] = concept1_constraint_climb(WS, obj, con_no)
%CONCEPT1_CONSTRAINT_CLIMB  Rate-of-climb constraint, turboprop powered.
%
%   [WP_max, extra] = concept1_constraint_climb(WS, obj, con_no)
%
%   Inputs
%     WS      takeoff wing loading (W/S)_TO [lbf/ft^2], scalar or row vector
%     obj     Concept 1 discipline bundle
%     con_no  index of the condition in obj.cons; the condition must carry
%             roc_fpm (required rate of climb, ft/min)
%   Outputs
%     WP_max  largest (W/P)_TO that still meets the rate of climb [lbf/hp]
%     extra   struct with the working (CL, CD, V, kP, eta_p)
%
%   Power balance in a steady climb (lift = weight, small-angle):
%
%       P_avail = P_req       eta_p kP P_SL = (D V + W ROC) / 550
%
%   Dividing by the weight W = beta W_TO and using D/W = CD/CL,
%
%       (W/P)_TO <= 550 eta_p kP / ( beta ( ROC + V CD/CL ) )
%
%   which has the same form as the cruise-speed constraint plus the ROC term.
%
%   FLIGHT SPEED. A best-rate-of-climb condition is flown at the
%   minimum-power speed, CL = sqrt(3 CD0 / K1). That CL is capped at
%   CL_climb = CLmax - stall margin from get_config_polar, so a draggy
%   configuration (takeoff flaps, stopped propeller) cannot be asked to fly
%   closer to the stall than the margin allows.
%
%   POWER. Turboprop power only; electric power is not credited, matching
%   concept1_climb. power_ratio applies the rating (max continuous or
%   takeoff), the one-engine-inoperative factor (n-1)/n, and the power
%   setting. The stopped-propeller drag increment is applied by
%   get_config_polar when the condition sets propeller_stopped.
%
%   LAPSE. Concept1HybridProp.power_lapse is flat with altitude (a stated
%   placeholder), so the 10,000 ft condition is optimistic until real
%   turboprop altitude data replaces it.

    con = get_con(con_no, obj.cons);
    raw = obj.cons(con_no);
    if ~isfield(raw, 'roc_fpm') || isempty(raw.roc_fpm)
        error('concept1_constraint_climb:MissingROC', ...
            'Condition %d carries no roc_fpm.', con_no);
    end
    ROC = raw.roc_fpm / 60;                      % ft/s

    state = get_state(con.alt);
    con.propulsion_mode = "turboprop";
    kP = obj.prop.power_ratio(state, con);
    if ~isfinite(kP) || kP <= 0
        error('concept1_constraint_climb:InvalidPowerRatio', ...
            'Climb turboprop power ratio must be positive and finite.');
    end

    cfg   = obj.aero.get_config_polar(state, con);
    eta_p = obj.prop.prop_eff(state, struct('type', "climb"));

    CL_minpower = sqrt(3 * cfg.CD0 / cfg.K1);
    CL = min(CL_minpower, cfg.CL_climb);
    CD = cfg.CD0 + cfg.K1 * CL^2;

    V = sqrt(2 * con.beta .* WS ./ (state.rho * CL));   % ft/s

    WP_max = 550 * eta_p * kP ./ (con.beta .* (ROC + V * (CD / CL)));

    extra = struct('CL', CL, 'CD', CD, 'LD', CL / CD, 'V_fps', V, ...
        'kP', kP, 'eta_p', eta_p, 'ROC_fps', ROC);
end
