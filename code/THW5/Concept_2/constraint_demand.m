function d = constraint_demand(WS, obj, con_no)
%CONSTRAINT_DEMAND Required propeller-input shaft hp per unit TAKEOFF weight.
% Source independent: power_source chooses who supplies this demand, never
% changes the aerodynamics. Multiply .hp_per_lbf by W_TO to obtain shaft hp.
% WS may be a vector for a fixed geometry; sizing must rebuild geometry for
% EACH candidate wing area, because CD0 depends on wetted area / wing area.
    validateattributes(WS, {'numeric'}, {'real','finite','positive','vector'});
    WS = reshape(WS, 1, []);
    c = get_con(con_no, obj.cons);
    s = get_state(c.alt);
    validateattributes(c.beta, {'numeric'}, {'scalar','finite','positive'});
    d = struct('condition', c, 'hp_per_lbf', NaN(size(WS)), ...
        'WS_wall', NaN, 'speed_ktas', NaN(size(WS)), 'model_status', "");
    switch string(c.type)
        case "landing"
            d.WS_wall = constraint_landing(obj, con_no);
            d.model_status = "provisional land-equivalent landing correlation";
        case "takeoff"
            % Existing Roskam Part I Sec. 3.1 TOP23 correlation. Its sigma
            % describes the field-performance correlation; do not apply a
            % piston engine power lapse to the electric source as well.
            TOP = max(roots([0.009, 4.9, -c.distance_ft]));
            d.hp_per_lbf = WS / (TOP * s.sigma * obj.aero.get_CLmax(s,c));
            d.model_status = "unvalidated land-equivalent water takeoff";
        case "water_hump"
            % T_required = margin * (R/displacement) * W_condition.
            % Divide by provisional thrust/hp to get shaft hp, NOT thrust hp.
            values = {c.margin,c.resistance_over_displacement,c.thrust_per_hp_at_hump};
            for k = 1:numel(values)
                validateattributes(values{k},{'numeric'},{'scalar','finite','positive'});
            end
            d.hp_per_lbf(:) = c.beta * c.margin * ...
                c.resistance_over_displacement / c.thrust_per_hp_at_hump;
            d.model_status = "provisional resistance and propeller thrust correlation";
        case "climb_gradient"
            cfg = constraint_polar(obj,s,c);
            CL = cfg.CL_climb;
            validateattributes(CL,{'numeric'},{'scalar','finite','positive'});
            LD = CL / (cfg.CD0 + cfg.K1 * CL^2);
            eta = obj.prop.prop_eff(s,c);
            % Algebraic inverse of Roskam Sec. 3.3 in constraint_climb:
            % beta^1.5 includes both condition W/P and sqrt(condition W/S).
            CGRP = (c.G + 1/LD)/sqrt(CL);
            d.hp_per_lbf = CGRP * c.beta^1.5 * sqrt(WS) / ...
                (18.97 * eta * sqrt(s.sigma));
            d.speed_ktas = sqrt(2*c.beta*WS/(s.rho*CL))*3600/6076.115;
            d.model_status = "inherited gradient; requirement status remains provisional";
        case "cruise_speed"
            if c.method ~= "drag_based"
                error('constraint_demand:DragBasedRequired', ...
                    'Source-specific cruise requires method=drag_based.');
            end
            V = c.ktas * 6076.115/3600;
            validateattributes(V,{'numeric'},{'scalar','finite','positive'});
            cfg = constraint_polar(obj,s,c);
            eta = obj.prop.prop_eff(s,struct('type',"cruise"));
            CL = c.beta*WS/(0.5*s.rho*V^2);
            if any(CL >= cfg.CLmax)
                % Infeasible aerodynamics must never pass with low demand.
                stalled = CL >= cfg.CLmax;
            else
                stalled = false(size(WS));
            end
            d.hp_per_lbf = c.beta*V*(cfg.CD0./CL + cfg.K1*CL)/(550*eta);
            d.hp_per_lbf(stalled) = Inf;
            d.speed_ktas(:) = c.ktas;
        case "climb_rate"
            validateattributes(c.roc_fpm,{'numeric'},{'scalar','finite','nonnegative'});
            cfg = constraint_polar(obj,s,c);
            eta = obj.prop.prop_eff(s,struct('type',"climb"));
            for j = 1:numel(WS)
                % Preliminary steady shallow-climb approximation L=W.
                % For constant eta, best ROC minimizes DV (minimum power).
                % CL_min_power=sqrt(3 CD0/K). Bound by the existing climb
                % stall margin and explicit speed limits when supplied.
                vlo = sqrt(2*c.beta*WS(j)/(s.rho*cfg.CL_climb));
                vhi = Inf;
                if ~isempty(c.speed_min_ktas)
                    vlo = max(vlo,c.speed_min_ktas*6076.115/3600);
                end
                if ~isempty(c.speed_max_ktas)
                    vhi = c.speed_max_ktas*6076.115/3600;
                end
                if vhi < vlo
                    d.hp_per_lbf(j) = Inf;
                    continue;
                end
                clopt = sqrt(3*cfg.CD0/cfg.K1);
                V = min(vhi,max(vlo,sqrt(2*c.beta*WS(j)/(s.rho*clopt))));
                CL = c.beta*WS(j)/(0.5*s.rho*V^2);
                d.hp_per_lbf(j) = c.beta * ...
                    (V*(cfg.CD0/CL+cfg.K1*CL)+c.roc_fpm/60)/(550*eta);
                d.speed_ktas(j) = V*3600/6076.115;
            end
            d.model_status = "steady shallow climb, constant prop efficiency, bounded minimum-power speed";
        otherwise
            error('constraint_demand:UndefinedType','Unknown constraint type %s.',c.type);
    end
end
