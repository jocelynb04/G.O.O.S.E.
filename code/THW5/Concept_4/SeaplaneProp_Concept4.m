classdef SeaplaneProp_Concept4 < handle
    properties
        J
        P_SL
        n_motors
        n_generators
        n_engines
        engine_shaft_power_sl_hp_each
        battery_capacity_kwh
        battery_initial_soc
        battery_min_soc
        battery_max_soc
        motor_continuous_fraction
        generator_continuous_fraction
        eta_generator
        eta_rectifier
        eta_inverter
        eta_motor
        eta_battery_discharge
        eta_battery_charge
        eta_p_cruise
        eta_p_climb
        eta_p_loiter
        BSFC
        generator_lapse_exponent
        battery_max_charge_bus_kw
        battery_max_discharge_bus_kw
        electric_only_phases
    end
    methods
        function obj = SeaplaneProp_Concept4(J)
            P = J.propulsion;
            if ~strcmp(char(P.architecture), 'series_hybrid')
                error('C4:Architecture', 'Propulsion architecture must be series_hybrid.');
            end
            obj.J = J;
            obj.P_SL = P.P_SL_hp;
            obj.n_motors = P.n_motors;
            obj.n_generators = P.n_generators;
            obj.n_engines = obj.n_generators;
            obj.engine_shaft_power_sl_hp_each = P.generator_engine_shaft_power_sl_hp_each;
            obj.battery_capacity_kwh = P.battery_capacity_kwh;
            obj.battery_initial_soc = P.battery_initial_soc;
            obj.battery_min_soc = P.battery_min_soc;
            obj.battery_max_soc = P.battery_max_soc;
            obj.motor_continuous_fraction = P.motor_continuous_fraction;
            obj.generator_continuous_fraction = P.generator_continuous_fraction;
            obj.eta_generator = P.generator_efficiency;
            obj.eta_rectifier = P.rectifier_efficiency;
            obj.eta_inverter = P.inverter_efficiency;
            obj.eta_motor = P.motor_efficiency;
            obj.eta_battery_discharge = P.battery_discharge_efficiency;
            obj.eta_battery_charge = P.battery_charge_efficiency;
            obj.eta_p_cruise = P.eta_p_cruise;
            obj.eta_p_climb = P.eta_p_climb;
            obj.eta_p_loiter = P.eta_p_loiter;
            obj.BSFC = P.BSFC_lb_per_hp_hr;
            obj.generator_lapse_exponent = P.generator_lapse_exponent;
            obj.battery_max_charge_bus_kw = P.battery_charge_power_limit_kw;
            obj.battery_max_discharge_bus_kw = P.battery_discharge_power_limit_kw;
            obj.electric_only_phases = cellstr(string(P.electric_only_phases));
            if obj.n_motors < 1 || obj.n_generators < 1
                error('C4:MotorCount', 'Motor and generator count must be positive.');
            end
            if ~(0 <= obj.battery_min_soc && obj.battery_min_soc < obj.battery_initial_soc && ...
                    obj.battery_initial_soc <= obj.battery_max_soc && obj.battery_max_soc <= 1)
                error('C4:SOC', 'Battery SOC bounds are invalid.');
            end
            eta = [obj.eta_generator obj.eta_rectifier obj.eta_inverter obj.eta_motor ...
                obj.eta_battery_charge obj.eta_battery_discharge obj.eta_p_cruise ...
                obj.eta_p_climb obj.eta_p_loiter];
            if any(~isfinite(eta) | eta<=0 | eta>1)
                error('C4:Efficiency', 'All efficiencies must be between zero and one.');
            end
        end
        function sigma = sigma_isa(~, altitude_ft)
            rho = isa_atmosphere_C4(altitude_ft);
            sigma = rho.rho_kg_m3 / 1.225;
        end
        function kW = generator_available_bus_kw(obj, altitude_ft, failed_generators)
            if nargin < 3, failed_generators = 0; end
            if failed_generators < 0 || failed_generators > obj.n_generators
                error('C4:GeneratorFailure', 'Invalid failed generator count.');
            end
            HP_TO_KW = 0.7456998715822702;
            n = obj.n_generators - failed_generators;
            hp = obj.engine_shaft_power_sl_hp_each*obj.generator_continuous_fraction * ...
                obj.sigma_isa(altitude_ft)^obj.generator_lapse_exponent;
            kW = n*hp*HP_TO_KW*obj.eta_generator*obj.eta_rectifier;
        end
        function kw = motor_bus_kw(obj, shaft_hp)
            if ~isfinite(shaft_hp) || shaft_hp < 0
                error('C4:Power', 'Shaft horsepower cannot be negative or nonfinite.');
            end
            kw = shaft_hp*0.7456998715822702/(obj.eta_motor*obj.eta_inverter);
        end
        function p = prop_eff(obj, phase)
            if strcmp(phase, 'climb') || strcmp(phase, 'balked_landing')
                p = obj.eta_p_climb;
            elseif strcmp(phase, 'loiter')
                p = obj.eta_p_loiter;
            else
                p = obj.eta_p_cruise;
            end
        end
        function phi = get_phi(obj, phase)
            if any(strcmp(phase, obj.electric_only_phases))
                phi = 1;
            else
                phi = c4_get(obj.J.propulsion.phi, phase, 0);
            end
        end
        function r = power_balance(obj, shaft_hp, duration_hr, alt_ft, phase, soc, battery_target, failed_generators, failed_motors, motor_rating)
            if nargin < 6 || isempty(soc), soc = obj.battery_initial_soc; end
            if nargin < 7 || isempty(battery_target), battery_target = obj.get_phi(phase); end
            if nargin < 8 || isempty(failed_generators), failed_generators = 0; end
            if nargin < 9 || isempty(failed_motors), failed_motors = 0; end
            if nargin < 10 || isempty(motor_rating), motor_rating = 'continuous'; end
            if ~isscalar(duration_hr) || ~isfinite(duration_hr) || duration_hr < 0
                error('C4:Duration', 'Duration must be finite and nonnegative.');
            end
            if failed_motors < 0 || failed_motors >= obj.n_motors
                error('C4:MotorFailure', 'Invalid failed motor count.');
            end
            if ~ismember(motor_rating, {'continuous', 'takeoff'})
                error('C4:MotorRating', 'Unknown motor rating.');
            end
            if ~isfinite(soc) || soc < obj.battery_min_soc || soc > obj.battery_max_soc
                error('C4:SOC', 'Initial SOC is outside operating bounds.');
            end
            available_hp = obj.P_SL*(obj.n_motors-failed_motors)/obj.n_motors;
            if strcmp(motor_rating, 'continuous')
                available_hp = available_hp*obj.motor_continuous_fraction;
            end
            if shaft_hp > available_hp + 1e-9
                error('C4:PowerUnavailable', 'Requested shaft power exceeds motor rating.');
            end
            electric_only = any(strcmp(phase, obj.electric_only_phases));
            if electric_only, battery_target = 1; end
            if ~isfinite(battery_target) || battery_target < -1 || battery_target > 1
                error('C4:BatteryShare', 'Battery target must be between -1 and 1.');
            end
            motor_kw = obj.motor_bus_kw(shaft_hp);
            if electric_only
                available_gen_kw = 0;
            else
                available_gen_kw = obj.generator_available_bus_kw(alt_ft, failed_generators);
            end
            target_gen_kw = max(0, motor_kw*(1-battery_target));
            gen_to_motor_kw = min([motor_kw target_gen_kw available_gen_kw]);
            bat_to_motor_kw = motor_kw-gen_to_motor_kw;
            charge_target_kw = max(0, target_gen_kw-motor_kw);
            charge_kw = min([charge_target_kw max(0,available_gen_kw-gen_to_motor_kw) obj.battery_max_charge_bus_kw]);
            if duration_hr > 0
                soc_charge_limit_kw = (obj.battery_max_soc-soc)*obj.battery_capacity_kwh / ...
                    (duration_hr*obj.eta_battery_charge);
                charge_kw = min(charge_kw, max(0,soc_charge_limit_kw));
            else
                charge_kw = 0;
            end
            if bat_to_motor_kw > 1e-9, charge_kw = 0; end
            battery_bus_kw = bat_to_motor_kw-charge_kw;
            generator_bus_kw = gen_to_motor_kw+charge_kw;
            if battery_bus_kw > obj.battery_max_discharge_bus_kw+1e-9
                error('C4:PowerUnavailable', 'Battery discharge limit exceeded.');
            end
            if battery_bus_kw >= 0
                delta_energy_kwh = battery_bus_kw*duration_hr/obj.eta_battery_discharge;
            else
                delta_energy_kwh = battery_bus_kw*duration_hr*obj.eta_battery_charge;
            end
            soc_end = soc-delta_energy_kwh/obj.battery_capacity_kwh;
            if soc_end < obj.battery_min_soc-1e-9
                error('C4:PowerUnavailable', 'Insufficient battery energy for segment.');
            end
            if soc_end > obj.battery_max_soc+1e-9
                error('C4:PowerUnavailable', 'Charge exceeds maximum battery SOC.');
            end
            engine_shaft_hp = generator_bus_kw/(obj.eta_generator*obj.eta_rectifier)/0.7456998715822702;
            fuel_lb = engine_shaft_hp*obj.BSFC*duration_hr;
            r = struct('phase', phase, 'shaft_power_hp', shaft_hp, 'duration_hr', duration_hr, ...
                'generator_bus_kw', generator_bus_kw, 'generator_available_bus_kw', available_gen_kw, ...
                'motor_bus_kw', motor_kw, 'battery_bus_kw', battery_bus_kw, ...
                'pack_energy_change_kwh', delta_energy_kwh, 'fuel_burn_lb', fuel_lb, ...
                'soc_start', soc, 'soc_end', max(obj.battery_min_soc,min(obj.battery_max_soc,soc_end)), ...
                'operating_motors', obj.n_motors-failed_motors, ...
                'operating_generators', obj.n_generators-failed_generators, ...
                'electric_only', electric_only);
        end
        function b = battery_mass_breakdown(obj, min_usable_energy_kwh, peak_battery_bus_kw)
            if nargin < 2 || isempty(min_usable_energy_kwh), min_usable_energy_kwh = 0; end
            if nargin < 3 || isempty(peak_battery_bus_kw)
                peak_battery_bus_kw = obj.motor_bus_kw(obj.P_SL);
            end
            P = obj.J.propulsion;
            usable = obj.battery_initial_soc-obj.battery_min_soc;
            capacity = max(obj.battery_capacity_kwh,min_usable_energy_kwh/usable);
            energy_mass = capacity/P.battery_specific_energy_kwh_per_kg;
            power_mass = peak_battery_bus_kw/obj.eta_battery_discharge/P.battery_specific_power_kw_per_kg;
            mass = max(energy_mass,power_mass);
            b = struct('energy_limited_mass_kg',energy_mass,'power_limited_mass_kg',power_mass, ...
                'battery_mass_kg',mass,'battery_mass_lb',mass*2.20462262185,'rated_capacity_kwh',capacity);
        end
        function b = installed_mass_breakdown(obj)
            P = obj.J.propulsion;
            hp_kw = 0.7456998715822702;
            kg_lb = 2.20462262185;
            motor_kw = obj.P_SL*hp_kw;
            inv_kw = obj.motor_bus_kw(obj.P_SL);
            engine_kw = obj.n_generators*obj.engine_shaft_power_sl_hp_each*hp_kw;
            gen_electric_kw = engine_kw*obj.eta_generator;
            battery = obj.battery_mass_breakdown();
            b = struct('battery_lb',battery.battery_mass_lb, ...
                'motors_lb',motor_kw/P.motor_specific_power_kw_per_kg*kg_lb, ...
                'motor_inverters_lb',inv_kw/P.inverter_specific_power_kw_per_kg*kg_lb, ...
                'generators_lb',gen_electric_kw/P.generator_specific_power_kw_per_kg*kg_lb, ...
                'turboshafts_lb',engine_kw/P.turboshaft_specific_power_kw_per_kg*kg_lb, ...
                'propellers_lb',obj.n_motors*P.propeller_mass_kg_each*kg_lb);
        end
    end
end
