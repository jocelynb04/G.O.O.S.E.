function m=hybrid_mission_energy(obj,W_TO,demands,contexts,cfg,J)
%HYBRID_MISSION_ENERGY Size BOL pack from all declared mission/failure cases.
% Bracket then bisect capacity; each trial integrates SOC, checks all source
% limits and recomputes static constraint SOC contexts from the traces.
% A finite maximum prevents endless "fixing" of a turbine/motor shortfall by
% adding battery mass. Infeasibility is returned with the actual reasons.
% Fuel includes explicit reserve ONCE, recharge, startup, idle, contingency
% and unusable allowance; only fuel burn reduces mission aircraft mass.
    if isempty(demands), error('hybrid_mission_energy:DemandRequired','Supply constraint demands.'); end
    cases=hybrid_mission_schedule(obj,W_TO,cfg,J);
    quantum=cfg.cell_series_count*cfg.battery_string_count*cfg.cell_nominal_energy_Wh/1000;
    maximum=floor(cfg.capacity_max_kWh/quantum)*quantum;
    if maximum<=0
        error('hybrid_mission_energy:CapacityBound','Capacity search bound is smaller than one complete pack increment.');
    end
    low=0; high=min(32,maximum);
    while true
        [ok,~,~,~]=trial(high,false);
        if ok || high>=maximum, break; end
        low=high; high=min(maximum,2*high);
    end
    bracketed=ok;
    if ok
        while high-low>cfg.capacity_tolerance_kWh
            mid=(high+low)/2;
            [valid,~,~,~]=trial(mid,false);
            if valid, high=mid; else, low=mid; end
        end
    end
    % Two equal independently isolatable strings require an integer cell
    % count. Round BOL nominal energy upward, then RECHECK the actual pack.
    high=ceil(high/quantum)*quantum;
    [ok,results,xs,report]=trial(high,true);
    modeledFuel=max([results.max_leg_fuel_lb]);
    profile=J.missions.std_mission;
    fuel=modeledFuel*(1+profile.reserve_fuel_fraction) / ...
        (1-profile.fuel_accounting.unusable_fuel_fraction_of_total_capacity);
    reasons=string({results.reason}); reasons=reasons(strlength(reasons)>0);
    bad=string({report.status})~="pass";
    reasons=[reasons,string({report(bad).name})+": "+string({report(bad).reason})];
    if ~bracketed, reasons(end+1)="No feasible pack within declared capacity search bound"; end
    if obj.geom.b>=cfg.span_limit_ft
        ok=false; reasons(end+1)="Wing span exceeds study65 ft strict limit";
    end
    m=struct('fuel_lb',fuel,'modeled_fuel_burn_lb',modeledFuel, ...
        'E_battery_nominal_kWh',high,'contexts',{xs}, ...
        'mission_feasible',logical(ok),'failure_checks_complete',logical(ok), ...
        'status',"preliminary study",'hardware_verified',false, ...
        'certification_compliance_established',false, ...
        'cases',results,'constraint_report',report,'reasons',unique(reasons), ...
        'capacity_bracketed',bracketed,'assumptions',cfg.status);

    function [good,outs,xs,r]=trial(E,traceRequested)
        outs=struct([]);
        % Trace is required to derive phase-specific constraint SOC even
        % during bracketing; strip it on intermediate trials to save memory.
        allTrace=struct([]);
        good=true;
        for ic=1:numel(cases)
            o=hybrid_soc_simulate(cases(ic).steps,E,obj,cfg,obj.prop.hybrid.battery_soc_max,true);
            o.name=cases(ic).name;
            o.route_distance_nm=cases(ic).route_distance_nm;
            o.cruise_ktas=cases(ic).cruise_ktas;
            o.legs=cases(ic).legs;
            o.reserve_case=cases(ic).reserve_case;
            if ~cases(ic).schedule_feasible
                o.feasible=false; o.reason=cases(ic).schedule_reason;
            end
            good=good && o.feasible;
            if ~isempty(o.trace), allTrace=[allTrace,o.trace]; end %#ok<AGROW>
            if ~traceRequested, o.trace=struct([]); end
            if isempty(outs), outs=o; else, outs(end+1)=o; end %#ok<AGROW>
        end
        xs=contexts;
        for ix=1:numel(xs)
            c=demands{ix}.condition;
            starts=[allTrace.soc_start];
            labels=string({allTrace.phase});
            if string(c.power_source)=="electric"
                if contains(c.name,'OEI')
                    mask=contains(labels,'OEI escape');
                elseif contains(c.name,'go-around') || contains(c.name,'BL')
                    mask=labels=="Electric go-around";
                elseif contains(c.name,'restart')
                    mask=contains(labels,'restart');
                elseif c.type=="takeoff" || c.type=="water_hump"
                    mask=labels=="Electric takeoff";
                else
                    mask=labels=="Electric departure climb";
                end
                if any(mask), starts=starts(mask); end
            end
            if isempty(starts), soc=obj.prop.hybrid.battery_soc_min;
            else, soc=max(obj.prop.hybrid.battery_soc_min,min(starts)); end
            xs{ix}.soc=soc;
            xs{ix}.E_battery_nominal_kWh=E;
        end
        r=evaluate_source_constraints(W_TO/obj.geom.S_ref,obj,W_TO,xs);
        good=good && all(string({r.status})=="pass");
    end
end
