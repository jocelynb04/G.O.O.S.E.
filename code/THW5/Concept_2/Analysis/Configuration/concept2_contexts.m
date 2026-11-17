function xs=concept2_contexts(obj,cfg)
%CONCEPT2_CONTEXTS Declared phase/failure assumptions for the study solver.
% SOC is filled by the mission calculation; 0.9 here is an initial planning
% value only. Pack capacity is injected by source_constraint_sizing.
    accessory=sum([cfg.accessories.kW].*[cfg.accessories.duty]);
    xs=cell(1,numel(obj.cons));
    for k=1:numel(obj.cons)
        c=get_con(k,obj.cons);
        f=1; if c.oei, f=.5; end
        duration=cfg.continuous_case_duration_min;
        if ~c.max_continuous, duration=min(1,cfg.turbine_takeoff_duration_min); end
        if c.type=="takeoff", duration=cfg.takeoff_min; end
        if c.type=="landing", duration=cfg.landing_min; end
        if contains(c.name,'restart'), duration=cfg.restart_delay_s/60; end
        if c.oei, duration=cfg.oei_checkpoint_duration_min; end
        fb=1;
        if c.oei && isfield(cfg,'failure_battery_fraction'), fb=cfg.failure_battery_fraction; end
        x=struct('duration_min',duration,'shaft_efficiency',cfg.shaft_efficiency, ...
            'gearbox_limit_hp',obj.prop.n_engines*cfg.gearbox_hp_each*f, ...
            'turbines_running',string(c.power_source)~="electric", ...
            'turbine_takeoff_duration_min',cfg.turbine_takeoff_duration_min, ...
            'turbine_survival_fraction',f,'motor_survival_fraction',f, ...
            'inverter_survival_fraction',f,'battery_survival_fraction',fb, ...
            'turbine_accessory_hp',0,'turbine_charge_hp',0, ...
            'accessory_dc_kW',0,'E_battery_nominal_kWh',NaN, ...
            'soc',obj.prop.hybrid.battery_soc_max, ...
            'battery_power_derating',cfg.battery_power_derating*cfg.battery_voltage_power_factor, ...
            'battery_energy_derating',cfg.battery_energy_derating);
        if string(c.power_source)=="electric"
            x.accessory_dc_kW=accessory;
        else
            x.turbine_accessory_hp=accessory/(.7457*.90);
        end
        xs{k}=x;
    end
end
