function out=hybrid_soc_simulate(steps,E,obj,cfg,initial_soc,keep_trace)
%HYBRID_SOC_SIMULATE Integrate one declared mission, preserving SOC across legs.
% Each precomputed step has raw source-shaft demand a+b*W^2+c*W. Fuel burn
% reduces W; battery mass never leaves the aircraft. At a new leg, refuelling
% restores takeoff weight but SOC is carried through with no ground charging.
% Charging uses only simultaneous turbine/gearbox/generator/inverter margin.
% Constant efficiencies and a linear high-SOC taper are study approximations.
    if nargin<6, keep_trace=true; end
    validateattributes(E,{'numeric'},{'scalar','finite','positive'});
    H=obj.prop.hybrid;
    eb=H.battery_efficiency; em=H.motor_efficiency; ei=H.inverter_efficiency;
    capacity=E*H.battery_end_of_life_capacity_fraction*cfg.battery_energy_derating;
    soc=initial_soc; minSOC=soc; totalFuel=0; legFuel=0; maxLegFuel=0;
    lastleg=steps(1).leg; peakTime=0; coolTime=0; batteryPeakTime=0; batteryCoolTime=0;
    good=true; reason=""; elapsed=0; discharged=0; charged=0;
    maxDC=0; maxMotor=0; maxTurbine=0; legEnds=[];
    trace=struct([]);
    for k=1:numel(steps)
        z=steps(k);
        if z.leg~=lastleg
            maxLegFuel=max(maxLegFuel,legFuel); legFuel=0;
            lastleg=z.leg; legEnds(end+1)=soc; %#ok<AGROW>
        end
        W=z.W_TO-legFuel;
        raw=max(0,z.a+z.b*W^2+z.c*W);
        if z.fraction>=0, raw=z.fraction*obj.prop.P_motor_peak; end
        dt=z.dt_min/60; before=soc; dc=0; storedCharge=0; turb=0;
        if W<=0 || (~isnan(z.q) && W/(z.q*obj.geom.S_ref)>=z.CLmax)
            good=false; reason="stall or nonpositive aircraft weight";
        end
        caphp=cfg.gearbox_hp_each*obj.prop.n_engines*z.f;
        if raw*cfg.shaft_efficiency>caphp+1e-7
            good=false; reason="shared gearbox capacity";
        end
        if z.source=="electric"
            motor=raw;
            rating=obj.prop.P_motor_continuous;
            C=cfg.battery_continuous_C;
            if z.peak, rating=obj.prop.P_motor_peak; C=cfg.battery_peak_C; end
            if motor>z.f*rating+1e-7
                good=false; reason="motor shaft rating";
            end
            driveDC=motor*.7457/(em*ei);
            if driveDC>z.f*obj.prop.P_inverter_rated_kW+1e-7
                good=false; reason="inverter motoring throughput";
            end
            dc=driveDC+z.accessory_dc_kW+z.restart_dc_kW;
            if dc>C*E*z.fb*cfg.battery_power_derating*cfg.battery_voltage_power_factor+1e-7
                good=false; reason="battery discharge power";
            end
            draw=dc*dt/eb;
            soc=soc-draw/(capacity*z.fb);
            discharged=discharged+draw;
            fuel=z.start_fuel_lb_hr*dt;
        else
            aux=z.accessory_dc_kW/(.7457*.90);
            available=min(z.turbine_hp,caphp/cfg.shaft_efficiency);
            if raw+aux>available+1e-7
                good=false; reason="turbine propulsion plus accessory power";
            end
            spare=max(0,available-raw-aux);
            genhp=min(spare,z.f*obj.prop.P_motor_continuous*cfg.generator_continuous_fraction);
            % Inverter rating is DC throughput, charge_C is DC pack input.
            storedLimit=min(z.f*obj.prop.P_inverter_rated_kW, ...
                cfg.battery_charge_C*E*z.fb*cfg.battery_power_derating*cfg.battery_voltage_power_factor) ...
                *cfg.charge_storage_efficiency;
            taper=min(1,max(0,(H.battery_soc_max-soc)/ ...
                (H.battery_soc_max-cfg.charge_taper_start_soc)));
            storedKW=min(genhp*.7457*H.recharge_chain_efficiency,storedLimit)*taper;
            storedCharge=min(storedKW*dt,max(0,H.battery_soc_max-soc)*capacity*z.fb);
            genhp=storedCharge/(dt*.7457*H.recharge_chain_efficiency);
            soc=soc+storedCharge/(capacity*z.fb);
            charged=charged+storedCharge;
            turb=raw+aux+genhp;
            motor=genhp; % same machine in generating operation, for duty check
            fuel=max(turb*obj.prop.BSFC, ...
                cfg.turbine_idle_fuel_lb_hr_each*obj.prop.n_engines*z.f)*dt;
        end
        % Peak duty is accumulated across phase boundaries. The recovery
        % rule is an explicit study policy, not an electrothermal model.
        if motor>z.f*obj.prop.P_motor_continuous+1e-7
            peakTime=peakTime+z.dt_min; coolTime=0;
        elseif motor<=.8*z.f*obj.prop.P_motor_continuous
            coolTime=coolTime+z.dt_min;
            if coolTime>=10, peakTime=0; end
        else
            coolTime=0;
        end
        if peakTime>H.motor_peak_duration_min+1e-9
            good=false; reason="accumulated peak duty";
        end
        % Battery peak duty is independent of motor duty: accessories can
        % push the pack above continuous C-rate with the motor below its limit.
        continuousDC=cfg.battery_continuous_C*E*z.fb*cfg.battery_power_derating ...
            *cfg.battery_voltage_power_factor;
        if dc>continuousDC+1e-7
            batteryPeakTime=batteryPeakTime+z.dt_min; batteryCoolTime=0;
        elseif dc<=.8*continuousDC
            batteryCoolTime=batteryCoolTime+z.dt_min;
            if batteryCoolTime>=10, batteryPeakTime=0; end
        else
            batteryCoolTime=0;
        end
        if batteryPeakTime>H.battery_peak_discharge_duration_min+1e-9
            good=false; reason="accumulated battery peak duty";
        end
        if soc<H.battery_soc_min-1e-8
            good=false; reason="battery SOC floor";
        end
        totalFuel=totalFuel+fuel; legFuel=legFuel+fuel;
        minSOC=min(minSOC,soc); elapsed=elapsed+z.dt_min;
        maxDC=max(maxDC,dc); maxMotor=max(maxMotor,motor); maxTurbine=max(maxTurbine,turb);
        if keep_trace
            row=struct('phase',z.name,'source',z.source,'leg',z.leg, ...
                'time_min',elapsed,'duration_min',z.dt_min,'alt_ft',z.alt, ...
                'W_lb',W,'soc_start',before,'soc_end',soc,'motor_hp',motor, ...
                'turbine_hp',turb,'battery_DC_kW',dc, ...
                'stored_charge_kWh',storedCharge,'fuel_lb',fuel,'battery_fraction',z.fb);
            if isempty(trace), trace=row; else, trace(end+1)=row; end %#ok<AGROW>
        end
        if ~good, break; end
    end
    legEnds(end+1)=soc;
    periodic=true;
    if max([steps.leg])>1
        periodic=numel(legEnds)==max([steps.leg]) && ...
            abs(legEnds(end)-legEnds(end-1))<=cfg.periodic_soc_tolerance && ...
            abs(legEnds(end)-legEnds(end-1))*capacity<=cfg.periodic_energy_tolerance_kWh;
        if ~periodic && good, reason="repeated-leg SOC does not balance"; end
    end
    out=struct('feasible',good && periodic,'completed',k==numel(steps) && good, ...
        'elapsed_min',elapsed,'reason',reason,'soc_min',minSOC, ...
        'soc_final',soc,'fuel_burn_lb',totalFuel,'max_leg_fuel_lb',max(maxLegFuel,legFuel), ...
        'stored_discharge_kWh',discharged,'stored_charge_kWh',charged, ...
        'max_battery_DC_kW',maxDC,'max_motor_hp',maxMotor, ...
        'max_turbine_hp',maxTurbine,'leg_end_soc',legEnds, ...
        'periodic_soc_balance',periodic,'trace',trace);
end
