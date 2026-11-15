classdef Concept1Weights < WeightsBase
%CONCEPT1WEIGHTS Preliminary component weight build-up for Concept 1.
% Twin parallel-hybrid turboprop flying boat with T-tail and tip floats.
% Based on TtpaWeights; compatible with WeightsBase and sizing loop.
%
% Accounting convention (IMPORTANT):
%   OEW includes empty structure, turboprops, electric motors, and equipment.
%   W_energy = W_fuel + W_battery, supplied by mission sizing later.
%   Battery mass is NOT included in OEW, to prevent double counting.
%   W_TO = OEW(W_TO) + W_energy + payload().
%
% Geometry and power must be initialized before calling OEW_breakdown.
% Added factors below are screening assumptions, not certified estimates.

    properties
        W_TO = NaN
        W_energy = NaN
        W_payload_expendable = 0
        W_payload_fixed = 1200

        % Adjustable Concept 1 assumptions
        float_structure_lb_per_ft2 = 1.4  % applied to float wetted area
        t_tail_structure_factor = 1.10    % horizontal + vertical tail only
        amphibious_gear_factor = 1.25    % multiplies baseline gear weight
        motor_installation_factor = 1.20 % motor plus installation allowance
    end

    properties (SetAccess = immutable)
        geom
        prop
        rho_wing
        rho_ht
        rho_vt
        rho_fuselage
        f_landing_gear
        f_installed_engine
        f_all_else_empty
        k_OEW_statistical
        n_OEW_statistical
        rho_fuel
    end

    methods
        function obj = Concept1Weights(json_path, geom, prop)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                geom (1,1) GeometryBase
                prop (1,1) PropulsionBase2
            end
            obj.geom = geom;
            obj.prop = prop;
            J = jsondecode(fileread(json_path));
            W = J.weights;

            obj.W_payload_fixed = W.W_payload_fixed;
            obj.W_payload_expendable = W.W_payload_expendable;
            obj.rho_wing = W.unit_weight_wing_psf;
            obj.rho_ht = W.unit_weight_horizontal_tail_psf;
            obj.rho_vt = W.unit_weight_vertical_tail_psf;
            obj.rho_fuselage = W.unit_weight_fuselage_psf;
            obj.f_landing_gear = W.landing_gear_fraction;
            obj.f_installed_engine = W.installed_engine_factor;
            obj.f_all_else_empty = W.all_else_empty_fraction;
            obj.k_OEW_statistical = W.statistical_OEW_coefficient;
            obj.n_OEW_statistical = W.statistical_OEW_exponent;
            obj.rho_fuel = W.fuel_density_lb_per_ft3;

            % Optional concept-specific overrides; existing JSON works.
            if isfield(W, 'concept1')
                C = W.concept1;
                names = {'float_structure_lb_per_ft2', ...
                    't_tail_structure_factor','amphibious_gear_factor', ...
                    'motor_installation_factor'};
                for i = 1:numel(names)
                    name = names{i};
                    if isfield(C, name)
                        obj.(name) = C.(name);
                    end
                end
            end
        end

        function oew = OEW(obj, W_TO)
            arguments
                obj
                W_TO (1,1) double {mustBePositive}
            end
            bd = obj.OEW_breakdown(W_TO);
            oew = bd.total;
        end

        function bd = OEW_breakdown(obj, W_TO)
            arguments
                obj
                W_TO (1,1) double {mustBePositive}
            end
            [W_bare_total, W_bare_each] = obj.prop.engine_weight();
            bd.engine_bare_each = W_bare_each;
            bd.engine_bare_total = W_bare_total;

            % Original professor's component build-up.
            bd.wing = obj.rho_wing * obj.geom.S_exposed_wing;
            bd.horizontal_tail = obj.rho_ht * obj.geom.S_ht * ...
                obj.t_tail_structure_factor;
            bd.vertical_tail = obj.rho_vt * obj.geom.S_vt * ...
                obj.t_tail_structure_factor;

            % Use the actual hull proxy, not the original fuselage area.
            bd.fuselage = obj.rho_fuselage * obj.geom.S_wet_hull;
            bd.floats = obj.float_structure_lb_per_ft2 * obj.geom.S_wet_floats;
            bd.landing_gear = obj.f_landing_gear * W_TO * ...
                obj.amphibious_gear_factor;
            bd.installed_engine = obj.f_installed_engine * W_bare_total;

            % Propulsion model returns motor-only weight; add allowance for
            % mount/inverter/coupling here. Battery is handled in W_energy.
            bd.electric_drive = obj.motor_installation_factor * ...
                obj.prop.electric_motor_weight();
            bd.all_else_empty = obj.f_all_else_empty * W_TO;

            bd.total = bd.wing + bd.horizontal_tail + bd.vertical_tail ...
                + bd.fuselage + bd.floats + bd.landing_gear ...
                + bd.installed_engine + bd.electric_drive + bd.all_else_empty;
        end

        function oew = OEW_statistical(obj, W_TO)
            arguments
                obj
                W_TO (1,1) double {mustBePositive}
            end
            % Conventional airplane cross-check only; not hybrid calibrated.
            oew = obj.k_OEW_statistical * W_TO ^ obj.n_OEW_statistical;
        end

        function W = payload(obj)
            W = obj.W_payload_fixed + obj.W_payload_expendable;
        end

        function [W_battery, W_fuel, W_energy] = energy_weights(obj, ...
                E_battery_required_kWh, W_fuel_lbf)
            % Helper for the future mission model. Do not add to OEW.
            arguments
                obj
                E_battery_required_kWh (1,1) double {mustBeNonnegative}
                W_fuel_lbf (1,1) double {mustBeNonnegative}
            end
            W_battery = obj.prop.battery_weight_lbf(E_battery_required_kWh);
            W_fuel = W_fuel_lbf;
            W_energy = W_battery + W_fuel;
            obj.W_energy = W_energy;
        end
    end
end
