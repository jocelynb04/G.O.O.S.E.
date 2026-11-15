classdef Concept1HybridProp < PropulsionBase2
%CONCEPT1HYBRIDPROP Preliminary Concept 1 twin-propeller parallel hybrid.
% Trade-study model, not a detailed powertrain simulation.
%
% P_SL is the sizing-loop REFERENCE installed power [hp], not the sum of
% turboprop and electric ratings. Each source has a separately adjustable
% ratio to P_SL; default ratios of 1 mean either source can independently
% supply the design-point shaft power. This is deliberately conservative.
%
% Operating schedule: electric for takeoff/landing/water operations;
% turboprop for climb/cruise/loiter unless explicitly overridden.
% Battery mass is constant during flight. Use battery_energy_kWh() and
% battery_weight_lbf() separately in the mission/weight models.

    properties
        engine_type = "Parallel Hybrid Turboprop"
        P_SL = NaN                 % sizing-loop reference power, total [hp]
        n_engines = 2             % two shared propellers / powertrains
        electric_power_ratio = 1  % total electric rated hp / P_SL
        turboprop_power_ratio = 1 % total turboprop rated hp / P_SL
        BSFC = 0.55               % ASSUMPTION: lb fuel/(hp*hr), turboprop only
        eta_p_cruise = 0.85       % preliminary assumptions
        eta_p_loiter = 0.80
        eta_p_climb = 0.80
        eta_p_takeoff = 0.75
        eta_p_landing = 0.70
        P_TO_over_P_max_continuous = 1.10
        eta_motor = 0.95
        eta_inverter = 0.97
        eta_gearbox = 0.98
        usable_battery_fraction = 0.80
        battery_specific_energy_Wh_kg = 250 % preliminary PACK-level assumption
        motor_specific_power_kW_kg = 5       % preliminary installed motor assumption
        turboprop_weight_lb_per_hp = 1.5    % PLACEHOLDER, replace with sourced data
        turboprop_length_ft = 4.0           % PLACEHOLDER, per powerplant
    end

    properties (Dependent)
        P_engine             % turboprop rated power per engine [hp]
        P_turboprop_SL       % combined turboprop rated shaft power [hp]
        P_electric_SL        % combined electric rated shaft power [hp]
    end

    methods
        function obj = Concept1HybridProp(json_path)
            % Optional: read existing professor JSON and override defaults.
            if nargin < 1 || isempty(json_path), return; end
            J = jsondecode(fileread(json_path));
            if ~isfield(J, 'propulsion'), return; end
            P = J.propulsion;
            if isfield(P,'n_engines'), obj.n_engines = P.n_engines; end
            if isfield(P,'eta_p_cruise'), obj.eta_p_cruise = P.eta_p_cruise; end
            if isfield(P,'eta_p_loiter'), obj.eta_p_loiter = P.eta_p_loiter; end
            if isfield(P,'eta_p_climb'), obj.eta_p_climb = P.eta_p_climb; end
            if isfield(P,'P_TO_over_P_max_continuous')
                obj.P_TO_over_P_max_continuous = P.P_TO_over_P_max_continuous;
            end
            % Do NOT copy piston-engine BSFC, weight or length regressions.
            names = {'electric_power_ratio','turboprop_power_ratio', ...
                'turboprop_BSFC_lb_per_hp_hr','eta_p_takeoff', ...
                'eta_p_landing','eta_motor','eta_inverter','eta_gearbox', ...
                'usable_battery_fraction','battery_specific_energy_Wh_kg', ...
                'motor_specific_power_kW_kg','turboprop_weight_lb_per_hp', ...
                'turboprop_length_ft'};
            for i = 1:numel(names)
                name = names{i};
                if isfield(P,name)
                    if strcmp(name,'turboprop_BSFC_lb_per_hp_hr')
                        obj.BSFC = P.(name);
                    else
                        obj.(name) = P.(name);
                    end
                end
            end
        end

        function val = get.P_turboprop_SL(obj)
            val = obj.P_SL * obj.turboprop_power_ratio;
        end
        function val = get.P_electric_SL(obj)
            val = obj.P_SL * obj.electric_power_ratio;
        end
        function val = get.P_engine(obj)
            val = obj.P_turboprop_SL / obj.n_engines;
        end

        function alpha = power_lapse(obj, state, rating)
            % Dimensionless turboprop power ratio vs reference P_SL.
            % A flat lapse is a placeholder for preliminary comparisons;
            % replace with sourced turboprop altitude performance later.
            if nargin < 3 || isempty(rating), rating = "takeoff"; end
            if nargin < 2, state = []; end %#ok<NASGU>
            alpha = obj.turboprop_power_ratio * obj.rating_factor(rating);
        end

        function kP = power_ratio(obj, state, con)
            % Available shaft power / reference P_SL at constraint condition.
            % Optional con.propulsion_mode = "electric" or "turboprop".
            mode = obj.mode_for_segment(con);
            if isfield(con,'max_continuous') && con.max_continuous
                rating = "max_continuous";
            else
                rating = "takeoff";
            end
            if mode == "electric"
                kP = obj.electric_power_ratio; % no atmospheric density lapse
            else
                kP = obj.power_lapse(state, rating);
            end
            if isfield(con,'oei') && con.oei
                % One of two independent propulsion units unavailable.
                kP = kP * (obj.n_engines - 1) / obj.n_engines;
            end
            if isfield(con,'power_setting')
                kP = kP * con.power_setting;
            end
        end

        function C = C_bhp(obj, ~, varargin)
            % Combustion-only BSFC; do not use for electric mission segments.
            C = obj.BSFC;
        end

        function eta = prop_eff(obj, ~, seg)
            switch lower(string(seg.type))
                case "cruise", eta = obj.eta_p_cruise;
                case "loiter", eta = obj.eta_p_loiter;
                case {"climb","climb_gradient"}, eta = obj.eta_p_climb;
                case {"takeoff","water_takeoff","taxi","water_taxi"}
                    eta = obj.eta_p_takeoff;
                case {"landing","water_landing"}, eta = obj.eta_p_landing;
                otherwise
                    error('Concept1HybridProp:UnknownSegment', ...
                        'No propeller efficiency for segment %s.',string(seg.type));
            end
        end

        function mode = mode_for_segment(~, seg)
            if isfield(seg,'propulsion_mode') && ~isempty(seg.propulsion_mode)
                mode = lower(string(seg.propulsion_mode));
            else
                switch lower(string(seg.type))
                    case {"takeoff","water_takeoff","landing", ...
                            "water_landing","taxi","water_taxi"}
                        mode = "electric";
                    otherwise
                        mode = "turboprop";
                end
            end
            if ~any(mode == ["electric","turboprop"])
                error('Concept1HybridProp:UnknownMode','Invalid mode %s.',mode);
            end
        end

        function P = available_power(obj, state, seg)
            % Total available shaft power [hp] for a condition/segment.
            mode = obj.mode_for_segment(seg);
            if mode == "electric"
                P = obj.P_electric_SL;
            else
                P = obj.P_SL * obj.power_lapse(state,"takeoff");
            end
        end

        function E_kWh = battery_energy_kWh(obj, P_shaft_hp, duration_hr)
            % Required battery energy drawn [kWh] for electric operation.
            E_kWh = 0.745699872 * P_shaft_hp * duration_hr / ...
                (obj.eta_motor * obj.eta_inverter * obj.eta_gearbox);
        end

        function W_lbf = battery_weight_lbf(obj, E_required_kWh)
            % Battery installed weight [lbf], including usable SOC fraction.
            mass_kg = 1000 * E_required_kWh / ...
                (obj.battery_specific_energy_Wh_kg * obj.usable_battery_fraction);
            W_lbf = mass_kg * 2.20462262;
        end

        function [W_total, W_each] = engine_weight(obj)
            % PRELIMINARY bare turboprop weight, excludes motors/batteries.
            W_each = obj.turboprop_weight_lb_per_hp * obj.P_engine;
            W_total = obj.n_engines * W_each;
        end

        function L = engine_length(obj)
            % Fixed placeholder nacelle-driving powerplant length [ft].
            L = obj.turboprop_length_ft;
        end

        function W_motor_lbf = electric_motor_weight(obj)
            % Preliminary motor weight only; no inverter/gearbox included.
            P_kW = obj.P_electric_SL * 0.745699872;
            W_motor_lbf = P_kW / obj.motor_specific_power_kW_kg * 2.20462262;
        end
    end

    methods (Access = private)
        function f = rating_factor(obj, rating)
            switch string(rating)
                case "takeoff", f = 1;
                case "max_continuous", f = 1 / obj.P_TO_over_P_max_continuous;
                otherwise
                    error('Concept1HybridProp:UnknownRating','Unknown rating %s.',string(rating));
            end
        end
    end
end
