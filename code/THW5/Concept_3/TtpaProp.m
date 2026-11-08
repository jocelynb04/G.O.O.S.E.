classdef TtpaProp < PropulsionBase2
%TTPAPROP  Series-hybrid electric propulsion model with distributed propulsion.
%
%   Power path: fuel -> turboshaft -> generator -> rectifier -> DC bus ->
%               inverter -> distributed electric motors -> propellers.
%               Battery <-> DC bus.
    properties
        engine_type = "Series hybrid-electric: generator + battery + distributed motors"
        P_SL = NaN
        % Total peak output power of all motor shafts at sea level [hp].
        n_motors
        n_generators
        n_engines                  % Alias for n_generators (turboshaft count)
        
        % Efficiency chain parameters
        BSFC                       % [lbm/(hp*hr)] at rated turboshaft output
        generator_continuous_fraction
        motor_continuous_fraction
        generator_lapse_exponent
        eta_generator
        eta_rectifier
        eta_inverter
        eta_motor
        eta_battery_discharge
        eta_battery_charge
        
        % Battery properties
        battery_capacity_kwh
        battery_initial_soc
        battery_min_soc
        battery_max_soc
        battery_max_charge_bus_kw
        battery_max_discharge_bus_kw
        
        % Specific power densities (kW/kg) and mass parameters
        battery_specific_energy_kwh_per_kg
        battery_specific_power_kw_per_kg
        motor_specific_power_kw_per_kg
        inverter_specific_power_kw_per_kg
        generator_specific_power_kw_per_kg
        turboshaft_specific_power_kw_per_kg
        propeller_mass_kg_each
        
        % Propeller efficiencies
        eta_p_cruise
        eta_p_loiter
        eta_p_climb
        
        P_TO_over_P_max_continuous
        
        % Engine-size regression (retained for compatibility / generators)
        engine_scaling_class
        k_W_engine
        n_W_engine
        k_L_engine
        n_L_engine
        bhp_range
    end
    properties (Dependent)
        P_engine
        % Rated shaft power of ONE motor [hp]. P_SL / n_motors.
    end
    methods (Access = private)
        %% Rating Factor
        function f = rating_factor(obj, rating)
            switch string(rating)
                case "takeoff"
                    f = 1;
                case "max_continuous"
                    f = 1 / obj.P_TO_over_P_max_continuous;
                otherwise
                    error('TtpaProp:UndefinedRating', ...
                        'Power rating "%s" is not defined.', string(rating));
            end
        end
    end
    methods
        %% Constructor
        function obj = TtpaProp(json_path)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
            end
            J = jsondecode(fileread(json_path));
            P = J.propulsion;
            
            % Architecture check & basic counts
            obj.n_motors   = P.n_motors;
            obj.n_generators = P.n_generators;
            obj.n_engines  = P.n_generators;  % Turboshaft count
            
            obj.P_SL       = P.P_SL_hp;
            obj.BSFC       = P.BSFC_lb_per_hp_hr;
            
            % Efficiencies
            obj.generator_continuous_fraction = P.generator_continuous_fraction;
            obj.motor_continuous_fraction     = P.motor_continuous_fraction;
            obj.generator_lapse_exponent      = P.generator_lapse_exponent;
            obj.eta_generator                 = P.generator_efficiency;
            obj.eta_rectifier                 = P.rectifier_efficiency;
            obj.eta_inverter                  = P.inverter_efficiency;
            obj.eta_motor                     = P.motor_efficiency;
            obj.eta_battery_discharge         = P.battery_discharge_efficiency;
            obj.eta_battery_charge            = P.battery_charge_efficiency;
            
            % Battery specs with MATLAB-compatible field checks
            obj.battery_capacity_kwh          = P.battery_capacity_kwh;
            obj.battery_initial_soc           = P.battery_initial_soc;
            obj.battery_min_soc               = P.battery_min_soc;
            if isfield(P, 'battery_max_soc')
                obj.battery_max_soc           = P.battery_max_soc;
            else
                obj.battery_max_soc           = 1.0;
            end
            obj.battery_max_charge_bus_kw     = P.battery_charge_power_limit_kw;
            obj.battery_max_discharge_bus_kw  = P.battery_discharge_power_limit_kw;
            
            % Specific powers & weights
            obj.battery_specific_energy_kwh_per_kg = P.battery_specific_energy_kwh_per_kg;
            obj.battery_specific_power_kw_per_kg   = P.battery_specific_power_kw_per_kg;
            obj.motor_specific_power_kw_per_kg     = P.motor_specific_power_kw_per_kg;
            obj.inverter_specific_power_kw_per_kg  = P.inverter_specific_power_kw_per_kg;
            obj.generator_specific_power_kw_per_kg = P.generator_specific_power_kw_per_kg;
            obj.turboshaft_specific_power_kw_per_kg= P.turboshaft_specific_power_kw_per_kg;
            obj.propeller_mass_kg_each             = P.propeller_mass_kg_each;
            
            obj.eta_p_cruise               = P.eta_p_cruise;
            obj.eta_p_loiter               = P.eta_p_loiter;
            obj.eta_p_climb                = P.eta_p_climb;
            obj.P_TO_over_P_max_continuous = P.P_TO_over_P_max_continuous;
            
            % Regression parameters
            obj.engine_scaling_class       = string(P.engine_scaling_class);
            obj.k_W_engine                 = P.engine_weight_coefficient;
            obj.n_W_engine                 = P.engine_weight_exponent;
            obj.k_L_engine                 = P.engine_length_coefficient;
            obj.n_L_engine                 = P.engine_length_exponent;
            obj.bhp_range                  = P.bhp_range_of_validity;
        end
        
        %% Power Per Motor
        function val = get.P_engine(obj)
            val = obj.P_SL / obj.n_motors;
        end
        
        %% Regression Guard
        function bhp = rated_bhp_per_engine(obj)
            bhp = obj.P_SL / obj.n_engines;
            if isnan(bhp)
                error('TtpaProp:PowerNotSet', 'PSL not set yet');
            elseif (bhp < obj.bhp_range(1)) || (bhp > obj.bhp_range(2))
                warning('TtpaProp:BhpOutOfRange', 'outside bhp_range');
            end
        end
        
        %% Generator Available Power at Altitude
        function bus_kw = generator_available_bus_kw(obj, altitude_ft, failed_generators)
            arguments
                obj
                altitude_ft (1,1) double
                failed_generators (1,1) double = 0
            end
            operating = obj.n_generators - failed_generators;
            
            % ISA density ratio approximation
            sigma = (1 - 6.8756e-6 * altitude_ft)^4.25588; 
            
            % FIXED: Clean multiplication and exponentiation operators
            per_engine_hp = (obj.P_SL / obj.n_generators) ...
                * obj.generator_continuous_fraction ...
                * (sigma ^ obj.generator_lapse_exponent);
            
            hp_to_kw = 0.74569987;
            bus_kw = operating * per_engine_hp * hp_to_kw ...
                * obj.eta_generator * obj.eta_rectifier;
        end
        
        %% Motor Bus Power Required
        function bus_kw = motor_bus_kw(obj, shaft_power_hp)
            hp_to_kw = 0.74569987;
            bus_kw = shaft_power_hp * hp_to_kw / (obj.eta_motor * obj.eta_inverter);
        end
        
        %% Installed Mass Breakdown (Series Hybrid Components)
        function masses = installed_mass_breakdown(obj)
            hp_to_kw = 0.74569987;
            kg_to_lb = 2.20462262;
            
            shaft_kw = obj.P_SL * hp_to_kw;
            bus_kw = obj.motor_bus_kw(obj.P_SL);
            engine_kw = (obj.n_generators * (obj.P_SL / obj.n_generators)) * hp_to_kw;
            
            battery_lb = obj.battery_mass_lb();
            
            masses = struct(...
                'battery_lb', battery_lb, ...
                'motors_lb', (shaft_kw / obj.motor_specific_power_kw_per_kg) * kg_to_lb, ...
                'motor_inverters_lb', (bus_kw / obj.inverter_specific_power_kw_per_kg) * kg_to_lb, ...
                'generators_lb', (engine_kw / obj.generator_specific_power_kw_per_kg) * kg_to_lb, ...
                'turboshafts_lb', (engine_kw / obj.turboshaft_specific_power_kw_per_kg) * kg_to_lb, ...
                'propellers_lb', (obj.n_motors * obj.propeller_mass_kg_each) * kg_to_lb ...
            );
        end
        
        function bat_lb = battery_mass_lb(obj)
            kg_to_lb = 2.20462262;
            energy_capacity_kwh = obj.battery_capacity_kwh;
            energy_mass_kg = energy_capacity_kwh / obj.battery_specific_energy_kwh_per_kg;
            
            peak_bus_kw = obj.motor_bus_kw(obj.P_SL);
            power_mass_kg = peak_bus_kw / obj.eta_battery_discharge / obj.battery_specific_power_kw_per_kg;
            
            bat_lb = max(energy_mass_kg, power_mass_kg) * kg_to_lb;
        end
        
        %% Engine Weight & Length (Raymer Regressions)
        function [W_total, W_each] = engine_weight(obj)
            bhp = obj.rated_bhp_per_engine();
            W_each  = obj.k_W_engine * bhp .^ obj.n_W_engine;
            W_total = W_each * obj.n_engines;
        end
        
        function L = engine_length(obj)
            bhp = obj.rated_bhp_per_engine();
            L   = obj.k_L_engine * bhp .^ obj.n_L_engine;
        end
        
        %% BSFC & Propeller Efficiency
        function C_bhp = C_bhp(obj, ~, ~)
            C_bhp = obj.BSFC;
        end
        
        function eta_p = prop_eff(obj, ~, miss_seg)
            switch lower(string(miss_seg.type))
                case "loiter"
                    eta_p = obj.eta_p_loiter;
                case "cruise"
                    eta_p = obj.eta_p_cruise;
                case {"climb", "climb_gradient"}
                    eta_p = obj.eta_p_climb;
                otherwise
                    error('TtpaProp:UndefinedSegment', ...
                        'Propeller efficiency is not defined for segment "%s".', ...
                        string(miss_seg.type));
            end
        end
    end
end
