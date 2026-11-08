classdef AMPH570Powertrain < handle
% AMP-H570 system rating model: combustion, electric boost and engine-driven recharge.
% Component split, altitude behavior, mass and charge maps remain explicit assumptions.
properties (SetAccess=private)
    config
    energy_kWh
    mass_lb
    motor_mass_lb = NaN % Included in powerplant assembly; not separately added.
    battery_mass_lb
    peak_elapsed_s = 0
end
methods
    function obj=AMPH570Powertrain(c)
        HybridPowertrain(c); % Reuse shared battery/efficiency/basic input validation.
        for key={'combined_peak_hp','combined_continuous_hp','combustion_max_hp', ...
                'peak_duration_limit_s_assumed','combustion_bsfc_lb_per_hp_hr', ...
                'powerplant_dry_mass_lb_assumed','battery_max_charge_C','charge_power_kW_assumed'}
            validateattributes(c.(key{1}),{'numeric'},{'scalar','positive','finite'});
        end
        for key={'removed_PT6_installed_mass_lb_assumed','flat_rating_alt_ft_assumed','lapse_exponent_above_flat_alt_assumed'}
            validateattributes(c.(key{1}),{'numeric'},{'scalar','nonnegative','finite'});
        end
        for key={'generator_efficiency','battery_charge_efficiency'}
            validateattributes(c.(key{1}),{'numeric'},{'scalar','>',0,'<=',1,'finite'});
        end
        validateattributes(c.charge_target_soc,{'numeric'},{'scalar','>=',c.minimum_soc,'<=',1,'finite'});
        assert(c.combined_continuous_hp<=c.combined_peak_hp && c.combustion_max_hp<=c.combined_peak_hp, ...
            'Hybrid:Ratings','Continuous/core ratings must not exceed combined peak.');
        obj.config=c; obj.energy_kWh=c.battery_capacity_kWh*c.initial_soc;
        obj.battery_mass_lb=c.battery_capacity_kWh*1000/c.battery_specific_energy_Wh_per_kg*2.20462262185;
        obj.mass_lb=c.powerplant_dry_mass_lb_assumed+c.installation_mass_kg*2.20462262185+ ...
            obj.battery_mass_lb-c.removed_PT6_installed_mass_lb_assumed;
    end
    function soc=get_soc(obj)
        soc=obj.energy_kWh/obj.config.battery_capacity_kWh;
    end
    function hp=combustion_available_hp(obj,state)
        c=obj.config;
        ratio=min(1,state.sigma/get_state(c.flat_rating_alt_ft_assumed).sigma);
        hp=c.combustion_max_hp*ratio^c.lapse_exponent_above_flat_alt_assumed;
    end
    function a=step(obj,P_hp,state,mode,fraction,dt_hr,~,fuel_available_lb)
        if nargin<8, fuel_available_lb=Inf; end
        validateattributes(P_hp,{'numeric'},{'scalar','nonnegative','finite'});
        validateattributes(dt_hr,{'numeric'},{'scalar','positive','finite'});
        c=obj.config; mode=string(mode); conv=.745699872;
        assert(P_hp<=min(c.combined_peak_hp,c.propeller_max_shaft_hp)+1e-9, ...
            'Hybrid:PropellerPower','Demand exceeds AMP-H570 combined peak shaft rating.');
        if P_hp>c.combined_continuous_hp+1e-9, next_peak=obj.peak_elapsed_s+dt_hr*3600;
        else, next_peak=0; end
        assert(next_peak<=c.peak_duration_limit_s_assumed+1e-8,'Hybrid:PeakDuration', ...
            'Demand exceeds assumed allowable continuous burst above combined max-continuous rating.');
        a.generator_shaft_kW=0;
        switch mode
            case "fuel", fraction=0;
            case "electric", fraction=1;
            case "hybrid"
                validateattributes(fraction,{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
            case "charge", fraction=0;
            otherwise, error('Hybrid:Mode','Mode must be fuel, electric, hybrid or charge.');
        end
        a.electric_shaft_kW=P_hp*fraction*conv;
        a.combustion_prop_hp=P_hp*(1-fraction);
        a.combustion_hp=a.combustion_prop_hp;
        available=obj.combustion_available_hp(state);
        assert(a.combustion_prop_hp<=available+1e-9,'Hybrid:CombustionPower', ...
            'Combustion-only propeller demand exceeds assumed altitude-adjusted core rating.');
        assert(a.electric_shaft_kW<=c.motor_max_shaft_kW+1e-9,'Hybrid:MotorPower', ...
            'Electric-only/boost demand exceeds modeled motor rating.');
        eta=c.motor_efficiency*c.inverter_efficiency*c.gearbox_efficiency;
        a.battery_kW=a.electric_shaft_kW/eta+c.hotel_load_kW;
        if mode=="charge"
            % Reversible machine: no simultaneous propulsive motor use and generation.
            gen_eta=c.generator_efficiency*c.inverter_efficiency*c.gearbox_efficiency;
            headroom=max(0,c.charge_target_soc*c.battery_capacity_kWh-obj.energy_kWh);
            charge_dc=min([c.charge_power_kW_assumed,c.battery_max_charge_C*c.battery_capacity_kWh, ...
                headroom/(c.battery_charge_efficiency*dt_hr)]);
            spare_kW=max(0,available-P_hp)*conv;
            generator_dc=min(c.hotel_load_kW+charge_dc,min(c.motor_max_shaft_kW,spare_kW)*gen_eta);
            a.generator_shaft_kW=generator_dc/gen_eta;
            a.combustion_hp=P_hp+a.generator_shaft_kW/conv;
            net_dc=c.hotel_load_kW-generator_dc;
            if net_dc<0, a.battery_kW=net_dc*c.battery_charge_efficiency;
            else, a.battery_kW=net_dc; end
        end
        assert(a.combustion_hp<=available+1e-8,'Hybrid:CombustionPower','Propulsion plus charging exceeds combustion rating.');
        assert(a.battery_kW<=c.battery_capacity_kWh*c.battery_max_discharge_C+1e-9, ...
            'Hybrid:BatteryPower','Battery discharge exceeds configured C-rate limit.');
        a.energy_kWh=a.battery_kW*dt_hr;
        nextE=obj.energy_kWh-a.energy_kWh;
        assert(nextE>=c.battery_capacity_kWh*c.minimum_soc-1e-9, ...
            'Hybrid:BatteryReserve','Battery minimum SOC would be violated.');
        assert(nextE<=c.battery_capacity_kWh+1e-9,'Hybrid:BatteryOvercharge','Battery capacity exceeded.');
        a.fuel_lb=c.combustion_bsfc_lb_per_hp_hr*a.combustion_hp*dt_hr;
        if mode~="electric", a.fuel_lb=max(a.fuel_lb,c.turbine_idle_fuel_lb_per_hr*dt_hr); end
        assert(a.fuel_lb<=fuel_available_lb,'Hybrid:FuelDepleted','Loaded fuel exhausted.');
        obj.energy_kWh=nextE; obj.peak_elapsed_s=next_peak;
        % Compatibility alias only; this engine is NOT a turbine.
        a.turbine_hp=a.combustion_hp;
    end
end
end
