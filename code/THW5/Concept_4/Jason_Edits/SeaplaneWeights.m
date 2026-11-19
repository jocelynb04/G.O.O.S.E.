classdef SeaplaneWeights < handle
    properties
        J
        geom
        prop
        W_TO = NaN
        W_energy = NaN
    end
    properties (Dependent)
        W_payload_fixed
    end
    methods
        function obj = SeaplaneWeights(J, geom, prop)
            obj.J = J;
            obj.geom = geom;
            obj.prop = prop;
        end
        function v = get.W_payload_fixed(obj)
            P = obj.J.payload;
            if P.baggage_includes_pilots
                bags = P.n_passengers + P.n_pilots;
            else
                bags = P.n_passengers;
            end
            v = P.n_passengers*P.W_passenger_lbf + P.n_pilots*P.W_pilot_lbf ...
                + bags*P.W_baggage_per_passenger_lbf;
        end
        function v = payload(obj)
            v = obj.W_payload_fixed + obj.J.payload.W_expendable_lbf;
        end
        function value = OEW(obj, W_TO)
            bd = obj.OEW_breakdown(W_TO);
            value = bd.total;
        end
        function bd = OEW_breakdown(obj, W_TO)
            if ~isfinite(W_TO) || W_TO <= 0
                error('C4:Weight', 'W_TO must be positive and finite.');
            end
            W = obj.J.weights;
            g = obj.geom;
            bd = struct();
            bd.wing = W.unit_weight_wing_psf*W.wing_motor_reinforcement_factor*g.S_exposed_wing;
            bd.horizontal_tail = W.unit_weight_horizontal_tail_psf*g.S_ht;
            bd.vertical_tail = W.unit_weight_vertical_tail_psf*W.cruciform_fin_factor*g.S_vt;
            bd.fuselage_hull = W.unit_weight_fuselage_psf*W.hull_factor*g.S_wet_fuselage;
            if ~strcmp(W.float_weight_model, 'fraction_of_W_TO')
                error('C4:FloatWeight', 'Only fraction_of_W_TO float weight model is implemented.');
            end
            bd.floats = W.float_weight_fraction*W_TO;
            bd.float_attachment = W.float_attachment_fraction*W_TO;
            if strcmp(W.landing_gear_variant, 'amphibious')
                bd.landing_gear = W.landing_gear_fraction*W_TO;
            elseif strcmp(W.landing_gear_variant, 'none')
                bd.landing_gear = 0;
            else
                error('C4:Gear', 'Unknown landing gear variant.');
            end
            masses = obj.prop.installed_mass_breakdown();
            names = fieldnames(masses);
            prop_mass = 0;
            for i = 1:numel(names)
                m = masses.(names{i});
                prop_mass = prop_mass + m;
                key = regexprep(names{i}, '_lb$', '');
                bd.(['prop_' key]) = m;
            end
            P = W.propulsion_integration;
            bd.prop_wiring = P.wiring_fraction_of_prop_mass*prop_mass;
            bd.prop_heat_sink = P.heat_sink_thermal_fraction_of_prop_mass*prop_mass;
            bd.prop_cowl_nacelle = P.cowl_nacelle_fraction_of_prop_mass*prop_mass;
            bd.prop_struts_mounting = P.struts_mounting_fraction_of_prop_mass*prop_mass;
            bd.prop_spinner = P.spinner_fraction_of_prop_mass*prop_mass;
            C = W.control_systems;
            bd.avionics_instruments = C.avionics_instruments_fraction*W_TO;
            bd.fuel_oil_system = C.fuel_oil_system_fraction*W_TO;
            bd.hydraulic_pneumatic = C.hydraulic_pneumatic_fraction*W_TO;
            bd.electrical_system = C.electrical_system_fraction*W_TO;
            bd.furnishings_seats = C.furnishings_seats_fraction*W_TO;
            bd.ice_protection = C.ice_protection_fraction*W_TO;
            names = fieldnames(bd);
            v = 0;
            for i = 1:numel(names), v = v + bd.(names{i}); end
            bd.total = v;
        end
    end
end
