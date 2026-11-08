classdef HybridPowertrain < handle
% Parallel turbine/motor, positive shaft power only, battery chemical-energy ledger.
properties (SetAccess=private)
    config
    energy_kWh
    mass_lb
    motor_mass_lb
    battery_mass_lb
end
methods
    function obj=HybridPowertrain(c)
        assert(string(c.architecture)=="parallel",'Hybrid:Architecture','Only parallel architecture is supported.');
        positive={'battery_capacity_kWh','battery_specific_energy_Wh_per_kg','battery_max_discharge_C', ...
            'motor_max_shaft_kW','motor_specific_power_kW_per_kg','propeller_max_shaft_hp','time_step_s'};
        for k=1:numel(positive), validateattributes(c.(positive{k}),{'numeric'},{'scalar','positive','finite'}); end
        for key={'motor_efficiency','inverter_efficiency','gearbox_efficiency'}
            validateattributes(c.(key{1}),{'numeric'},{'scalar','>',0,'<=',1,'finite'});
        end
        for key={'installation_mass_kg','hotel_load_kW','fuel_loaded_lb','payload_lb','turbine_idle_fuel_lb_per_hr'}
            validateattributes(c.(key{1}),{'numeric'},{'scalar','nonnegative','finite'});
        end
        assert(isfinite(c.initial_soc) && isfinite(c.minimum_soc) && ...
            c.initial_soc<=1 && c.initial_soc>c.minimum_soc && c.minimum_soc>=0, ...
            'Hybrid:SOCInput','Require 0 <= minimum SOC < initial SOC <= 1.');
        obj.config=c; obj.energy_kWh=c.battery_capacity_kWh*c.initial_soc;
        obj.battery_mass_lb=c.battery_capacity_kWh*1000/c.battery_specific_energy_Wh_per_kg*2.20462262185;
        obj.motor_mass_lb=c.motor_max_shaft_kW/c.motor_specific_power_kW_per_kg*2.20462262185;
        obj.mass_lb=obj.battery_mass_lb+obj.motor_mass_lb+c.installation_mass_kg*2.20462262185;
    end
    function soc=get_soc(obj)
        soc=obj.energy_kWh/obj.config.battery_capacity_kWh;
    end
    function a=step(obj,P_hp,state,mode,fraction,dt_hr,prop,fuel_available_lb)
        if nargin<8, fuel_available_lb=Inf; end
        validateattributes(P_hp,{'numeric'},{'scalar','nonnegative','finite'});
        validateattributes(dt_hr,{'numeric'},{'scalar','positive','finite'});
        c=obj.config;
        switch string(mode)
            case "fuel", fraction=0;
            case "electric", fraction=1;
            case "hybrid"
                validateattributes(fraction,{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
            otherwise, error('Hybrid:Mode','Mode must be fuel, electric or hybrid.');
        end
        assert(P_hp<=c.propeller_max_shaft_hp+1e-9,'Hybrid:PropellerPower','Combined shaft power exceeds propeller/drivetrain rating.');
        a.electric_shaft_kW=P_hp*fraction*0.745699872;
        a.turbine_hp=P_hp*(1-fraction);
        available=prop.P_SL*prop.power_lapse(state,"max_continuous");
        assert(a.turbine_hp<=available+1e-9,'Hybrid:TurbinePower','Turbine demand exceeds altitude-adjusted available power.');
        assert(a.electric_shaft_kW<=c.motor_max_shaft_kW+1e-9,'Hybrid:MotorPower','Electric demand exceeds motor continuous rating.');
        eta=c.motor_efficiency*c.inverter_efficiency*c.gearbox_efficiency;
        a.battery_kW=a.electric_shaft_kW/eta+c.hotel_load_kW;
        assert(a.battery_kW<=c.battery_capacity_kWh*c.battery_max_discharge_C+1e-9, ...
            'Hybrid:BatteryPower','Battery discharge power exceeds configured C-rate limit.');
        a.energy_kWh=a.battery_kW*dt_hr;
        assert(obj.energy_kWh-a.energy_kWh>=c.battery_capacity_kWh*c.minimum_soc-1e-9, ...
            'Hybrid:BatteryReserve','Selected mode would use the battery SOC reserve.');
        a.fuel_lb=prop.C_bhp(state)*a.turbine_hp*dt_hr;
        if string(mode)~="electric"
            a.fuel_lb=max(a.fuel_lb,c.turbine_idle_fuel_lb_per_hr*dt_hr);
        end
        assert(a.fuel_lb<=fuel_available_lb,'Hybrid:FuelDepleted','Selected schedule exhausted loaded fuel.');
        obj.energy_kWh=obj.energy_kWh-a.energy_kWh;
    end
end
end
