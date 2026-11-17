function a = source_power_available(prop, state, con, x)
%SOURCE_POWER_AVAILABLE Aircraft-total usable hp at the propeller input.
% Turbine catalog output and motor ratings are upstream of the declared
% common shaft efficiency. Shared gearbox capacity caps their SUM.
% Every context value is caller supplied: []/NaN is unresolved, never zero
% loss, unlimited duration, full SOC, or an automatically running turbine.
    src = string(con.power_source);
    if ~isscalar(src) || ~any(src == ["electric","turbine","both"])
        error('source_power_available:InputRequired','A valid power_source is required.');
    end
    etaS = number(x,'shaft_efficiency',0,1);
    gearbox = number(x,'gearbox_limit_hp',0,Inf);
    setting = con.power_setting;
    validateattributes(setting,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
    if (~isfield(x,'duration_min') || isempty(x.duration_min)) && ...
            isfield(con,'duration_min') && ~isempty(con.duration_min)
        x.duration_min=con.duration_min;
    end
    duration = number(x,'duration_min',0,Inf);
    if duration == 0
        error('source_power_available:InputRequired','duration_min must be positive.');
    end
    a = struct('turbine_hp',0,'motor_hp',0,'total_hp',0, ...
        'motor_survival_fraction',0,'turbine_survival_fraction',0, ...
        'shaft_efficiency',etaS,'gearbox_limit_hp',gearbox, ...
        'motor_rating_hp',0,'battery_terminal_kW',0,'motor_nonrating_hp',0);
    if src == "turbine" || src == "both"
        running = number(x,'turbines_running',0,1);
        if running ~= 0 && running ~= 1
            error('source_power_available:InputRequired','turbines_running must be logical.');
        end
        f = survival(x,'turbine',con.oei);
        a.turbine_survival_fraction = f;
        rating = "takeoff";
        if con.max_continuous
            rating = "max_continuous";
        elseif running && duration > number(x,'turbine_takeoff_duration_min',0,Inf)
            error('source_power_available:DurationExceeded','Turbine takeoff duration exceeded.');
        end
        % Catalog charts have their own installation boundary. Only NEW
        % aircraft loads declared here are subtracted, once, in shaft hp.
        loadhp = number(x,'turbine_accessory_hp',0,Inf) + ...
            number(x,'turbine_charge_hp',0,Inf);
        turbine=0;
        if running
            turbine=setting*f*prop.turbine_power_available(state,rating);
        end
        if loadhp>turbine+1e-9
            error('source_power_available:AuxiliaryPowerExceeded', ...
                'Turbine accessory/charging loads exceed available turbine shaft power.');
        end
        a.turbine_hp=etaS*max(0,turbine-loadhp);
    end
    if src == "electric" || src == "both"
        H = prop.hybrid;
        f = survival(x,'motor',con.oei);
        fi = survival(x,'inverter',con.oei);
        fb = survival(x,'battery',con.oei);
        a.motor_survival_fraction = f;
        em = number(H,'motor_efficiency',0,1);
        ei = number(H,'inverter_efficiency',0,1);
        eb = number(H,'battery_efficiency',0,1);
        E = number(x,'E_battery_nominal_kWh',0,Inf);
        soc = number(x,'soc',0,1);
        socmin = number(H,'battery_soc_min',0,1);
        socmax = number(H,'battery_soc_max',socmin,1);
        if soc < socmin || soc > socmax
            error('source_power_available:InvalidSOC','SOC is outside the declared usable window.');
        end
        eol = number(H,'battery_end_of_life_capacity_fraction',0,1);
        derate = number(x,'battery_power_derating',0,1);
        energyderate = number(x,'battery_energy_derating',0,1);
        accessory = number(x,'accessory_dc_kW',0,Inf);
        if con.max_continuous
            motor = prop.P_motor_continuous;
            C = number(H,'battery_max_continuous_discharge_C',0,Inf);
        else
            motor = prop.P_motor_peak;
            if duration > number(H,'motor_peak_duration_min',0,Inf) || ...
                    duration > number(H,'battery_peak_discharge_duration_min',0,Inf)
                error('source_power_available:DurationExceeded','Electric peak duration exceeded.');
            end
            C = number(H,'battery_max_discharge_C',0,Inf);
        end
        if ~(isscalar(motor) && isfinite(motor) && motor>=0 && ...
                isscalar(prop.P_inverter_rated_kW) && ...
                isfinite(prop.P_inverter_rated_kW) && prop.P_inverter_rated_kW>=0)
            error('source_power_available:InputRequired', ...
                'Set finite motor and DC-side inverter ratings before availability evaluation.');
        end
        % C-rate is referenced to BOL nominal kWh per the requirements JSON.
        % Energy limit uses EOL usable stored energy, then discharge loss.
        % Explicit deratings avoid implying temperature/rate data exist.
        rateDC = C*E*fb*derate;
        energyDC = E*fb*eol*energyderate*(soc-socmin)*eb/(duration/60);
        if accessory>min(rateDC,energyDC)+1e-9
            error('source_power_available:AuxiliaryPowerExceeded', ...
                'Battery power/energy cannot support the declared DC accessory load.');
        end
        batteryDC = max(0,min(rateDC,energyDC)-accessory);
        a.battery_terminal_kW = batteryDC;
        a.motor_rating_hp = setting*f*motor;
        % Separate the fixed electrical ceiling for conditional motor-sizing
        % diagrams. Increasing a motor nameplate cannot increase this limit.
        a.motor_nonrating_hp = etaS * min([ ...
            fi*prop.P_inverter_rated_kW*ei*em/0.7457, ...
            batteryDC*ei*em/0.7457]);
        a.motor_hp = min(etaS*a.motor_rating_hp,a.motor_nonrating_hp);
    end
    % Individual fields are source contributions before the shared cap.
    a.total_hp = min(gearbox,a.turbine_hp+a.motor_hp);
end

function v = number(s,field,lo,hi)
    if ~isfield(s,field) || isempty(s.(field)) || ...
            ~(isnumeric(s.(field)) || islogical(s.(field))) || ...
            ~isscalar(s.(field)) || ~isreal(s.(field)) || ...
            ~isfinite(s.(field)) || s.(field) < lo || s.(field) > hi
        error('source_power_available:InputRequired', ...
            'Supply a finite %s in [%g,%g]; missing data are not unlimited.',field,lo,hi);
    end
    v = double(s.(field));
    if contains(field,'efficiency') && v == 0
        error('source_power_available:InputRequired','%s must be positive.',field);
    end
end

function f = survival(x,source,oei)
    % OEI has no universal 50%% rule for batteries/common DC buses. Explicit
    % fractions model the declared failure topology. Even AEO fractions are
    % explicit so a disconnected/damaged subsystem can be represented.
    f = number(x,[source '_survival_fraction'],0,1);
    if ~oei && f ~= 1
        error('source_power_available:InvalidFailure', ...
            'AEO %s survival fraction must be one.',source);
    end
    if oei && source == "motor" && f == 1
        error('source_power_available:InvalidFailure', ...
            'OEI means a failed propulsor: declare surviving motor fraction.');
    end
    if oei && source == "turbine" && f == 1
        error('source_power_available:InvalidFailure', ...
            'OEI means a failed propulsor: declare surviving turbine fraction.');
    end
end
