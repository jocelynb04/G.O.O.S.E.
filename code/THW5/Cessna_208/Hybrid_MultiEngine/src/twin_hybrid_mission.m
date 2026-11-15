function r=twin_hybrid_mission(J)
% Propagate one side of an exactly symmetric two-powertrain mission.
c=J.hybrid;
installation=J.installation;
p=grand_caravan_ex_params();
o=ttpa_disciplines();
removedPT6=c.removed_PT6_installed_mass_lb_assumed;
c.removed_PT6_installed_mass_lb_assumed=0;
power=AMPH570Powertrain(c);
segments=json_as_struct_array(J.segments);
r.aircraft="Conceptual twin hybrid Grand Caravan EX Amphibian";
r.weight_breakdown=table( ...
    ["Baseline empty";"Remove nose PT6 installation";"Two wing powertrains"; ...
    "Nose cone";"Wing reinforcement";"Nose equipment"], ...
    [o.wts.OEW(p.MTOW_lb);-removedPT6;2*power.mass_lb; ...
    installation.nosecone_mass_lb;installation.wing_reinforcement_lb;installation.nose_equipment_lb], ...
    'VariableNames',{'Item','Weight_lb'});
r.hybrid_empty_lb=sum(r.weight_breakdown.Weight_lb);
r.battery_mass_lb=2*power.battery_mass_lb;
r.payload_lb=c.payload_lb;
r.initial_weight_lb=r.hybrid_empty_lb+c.payload_lb+c.fuel_loaded_lb;
r.mtow_margin_lb=p.MTOW_lb-r.initial_weight_lb;
r.tank_margin_lb=p.usable_fuel_lb-c.fuel_loaded_lb;
r.fuel_capacity_at_payload_lb=min(p.usable_fuel_lb,p.MTOW_lb-r.hybrid_empty_lb-c.payload_lb);
r.fuel_capacity_at_800_lb_payload_lb=min(p.usable_fuel_lb,p.MTOW_lb-r.hybrid_empty_lb-800);
r.feasible=false; r.failure=""; r.failure_segment=""; current_name="Loading"; r.segments=struct([]);
r.trace=struct('time_min',0,'soc',power.get_soc(),'weight_lb',r.initial_weight_lb, ...
    'fuel_remaining_lb',c.fuel_loaded_lb,'shaft_hp',0,'combustion_hp',0,'generator_shaft_kW',0,'electric_shaft_kW',0,'battery_kW',0,'segment_index',0);
W=r.initial_weight_lb; fuel=c.fuel_loaded_lb; elapsed=0; h_previous=0;
try
    assert(r.mtow_margin_lb>=0,'Hybrid:MTOW','Loaded aircraft exceeds reference MTOW.');
    assert(r.tank_margin_lb>=0,'Hybrid:Tank','Loaded fuel exceeds reference usable fuel capacity.');
    for k=1:numel(segments)
        s=segments(k); current_name=string(s.name); kind=string(s.type); mode=string(s.mode);
        assert(any(kind==["ground","climb","cruise","loiter","descent"]),'Hybrid:SegmentType','Unknown segment type.');
        if kind=="ground"
            h0=s.alt_ft; h1=h0; duration=s.duration_min*60; V=NaN; vz=0;
            validateattributes(s.shaft_power_hp,{'numeric'},{'scalar','nonnegative','finite'});
        else
            validateattributes(s.ktas,{'numeric'},{'scalar','positive','finite'});
            V=s.ktas*6076.11549/3600;
            if any(kind==["climb","descent"])
                h0=s.start_alt_ft; h1=s.end_alt_ft;
                if isfield(s,'flight_path_angle_deg') && ~isempty(s.flight_path_angle_deg)
                    validateattributes(s.flight_path_angle_deg,{'numeric'},{'scalar','>',-30,'<',30,'finite'});
                    vz=V*sind(s.flight_path_angle_deg);
                else
                    validateattributes(s.vertical_speed_fpm,{'numeric'},{'scalar','finite'});
                    vz=s.vertical_speed_fpm/60;
                end
                assert(abs(vz)<V && ((kind=="climb" && h1>h0 && vz>0) || ...
                    (kind=="descent" && h1<h0 && vz<0)), ...
                    'Hybrid:Path','Altitude change and vertical speed must agree with segment type.');
                duration=(h1-h0)/vz;
            else
                h0=s.alt_ft; h1=h0; vz=0;
                if kind=="cruise", duration=s.distance_nm/s.ktas*3600;
                else, duration=s.duration_min*60; end
            end
        end
        validateattributes([h0,h1],{'numeric'},{'>=',0,'<=',20000,'finite'});
        assert(abs(h0-h_previous)<1e-6,'Hybrid:AltitudeContinuity','Segment start altitude differs from previous end altitude.');
        validateattributes(duration,{'numeric'},{'scalar','positive','finite'});
        n=ceil(duration/c.time_step_s); dt=duration/n; startW=W; startFuel=fuel; startE=power.energy_kWh;
        maxP=0; maxCL=0; clipped=false;
        for i=1:n
            alt=h0+(h1-h0)*(i-.5)/n; st=get_state(alt);
            if kind=="ground"
                P=s.shaft_power_hp; CL=NaN;
            else
                con=struct('config',s.config,'propeller_stopped',false);
                polar=o.aero.get_config_polar(st,con);
                q=.5*st.rho*V^2; CL=W*sqrt(1-(vz/V)^2)/(q*o.geom.S_ref);
                assert(CL<=polar.CLmax-o.aero.CL_stall_margin,'Hybrid:StallMargin','Flight schedule violates configured lift-coefficient stall margin.');
                D=q*o.geom.S_ref*(polar.CD0+installation.net_drag_CD0_increment+polar.K1*CL^2);
                if kind=="cruise", eta=o.prop.eta_p_cruise;
                elseif kind=="loiter", eta=o.prop.eta_p_loiter;
                else, eta=o.prop.eta_p_climb; end
                raw=(D*V+W*vz)/(550*eta); clipped=clipped || raw<0;
                P=max(0,raw); % Excess descent energy is dissipated; no regeneration.
            end
            fraction=0;
            if mode=="hybrid"
                assert(isfield(s,'electric_fraction') && ~isempty(s.electric_fraction), ...
                    'Hybrid:MissingSplit','Hybrid segments require electric_fraction.');
                fraction=s.electric_fraction;
            end
            % step is transactional for battery errors; fuel checked before committing result.
            a=power.step(P/2,st,mode,fraction,dt/3600,o.prop,fuel/2);
            assert(fuel>=2*a.fuel_lb,'Hybrid:FuelDepleted','Selected schedule exhausted loaded fuel.');
            fuel=fuel-2*a.fuel_lb; W=W-2*a.fuel_lb; elapsed=elapsed+dt;
            r.trace.time_min(end+1)=elapsed/60; r.trace.soc(end+1)=power.get_soc();
            r.trace.weight_lb(end+1)=W; r.trace.fuel_remaining_lb(end+1)=fuel;
            r.trace.shaft_hp(end+1)=P; r.trace.combustion_hp(end+1)=2*a.combustion_hp; r.trace.generator_shaft_kW(end+1)=2*a.generator_shaft_kW;
            r.trace.electric_shaft_kW(end+1)=2*a.electric_shaft_kW;
            r.trace.battery_kW(end+1)=2*a.battery_kW; r.trace.segment_index(end+1)=k;
            maxP=max(maxP,P); if isfinite(CL), maxCL=max(maxCL,CL); end
        end
        row=struct('name',string(s.name),'mode',mode,'duration_min',duration/60, ...
            'fuel_lb',startFuel-fuel,'battery_kWh',2*(startE-power.energy_kWh), ...
            'end_soc',power.get_soc(),'start_weight_lb',startW,'end_weight_lb',W, ...
            'weight_fraction',W/startW,'peak_shaft_hp',maxP,'peak_CL',maxCL, ...
            'descent_energy_dissipated',clipped);
        if k==1, r.segments=row; else, r.segments(k)=row; end
        h_previous=h1;
    end
    r.feasible=true;
catch err
    if ~startsWith(string(err.identifier),"Hybrid:"), rethrow(err); end
    r.failure_segment=current_name; r.failure=string(err.identifier)+": "+string(err.message);
end
% Trace contains committed steps only, including on failure.
r.final_soc=r.trace.soc(end); r.fuel_used_lb=c.fuel_loaded_lb-r.trace.fuel_remaining_lb(end);
r.fuel_remaining_lb=r.trace.fuel_remaining_lb(end);
r.battery_used_kWh=2*(c.initial_soc-r.final_soc)*c.battery_capacity_kWh;
r.final_weight_lb=r.trace.weight_lb(end);
r.mass_balance_error_lb=r.initial_weight_lb-r.final_weight_lb-r.fuel_used_lb;
r.battery_reserve_kWh=2*c.battery_capacity_kWh*c.minimum_soc;
r.battery_energy_margin_kWh=2*r.final_soc*c.battery_capacity_kWh-r.battery_reserve_kWh;
r.completed_segments=numel(r.segments);
r.battery_discharged_kWh=sum(max(r.trace.battery_kW(2:end),0).*diff(r.trace.time_min)/60);
r.battery_recharged_kWh=-sum(min(r.trace.battery_kW(2:end),0).*diff(r.trace.time_min)/60);
r.battery_energy_balance_error_kWh=r.battery_used_kWh-r.battery_discharged_kWh+r.battery_recharged_kWh;
end

