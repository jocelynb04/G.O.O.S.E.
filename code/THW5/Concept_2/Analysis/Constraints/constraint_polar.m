function cfg = constraint_polar(obj, state, con)
%CONSTRAINT_POLAR Configuration and failed-propeller drag at one condition.
% The old stopped-propeller increment is NOT a feathered-propeller model.
% Require a separately documented increment when feathering is credited.
    if ~isempty(con.failed_propeller_state)
        mode = string(con.failed_propeller_state);
        if mode == "feathered"
            Jinc = obj.aero.dCD0_propeller_feathered;
            if isfinite(obj.aero.feathered_drag_area_ft2)
                Jinc=obj.aero.feathered_drag_area_ft2/obj.geom.S_ref;
            end
            if ~(isscalar(Jinc) && isfinite(Jinc) && Jinc >= 0)
                error('constraint_polar:FeatheredDragRequired', ...
                    'Supply aerodynamics.delta_CD0_propeller_feathered for %s.',con.name);
            end
            con.propeller_stopped = false;
            cfg = obj.aero.get_config_polar(state,con);
            cfg.CD0 = cfg.CD0 + Jinc;
            return;
        elseif mode ~= "stopped"
            error('constraint_polar:UnknownPropellerState','Unsupported failed propeller state %s.',mode);
        else
            con.propeller_stopped = true;
        end
    end
    cfg = obj.aero.get_config_polar(state,con);
end
