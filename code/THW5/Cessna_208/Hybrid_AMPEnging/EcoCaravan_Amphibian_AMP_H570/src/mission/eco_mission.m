function r=eco_mission(path)
% Fixed airframe, explicit fuel/battery ledger. No original sizing-loop substitution.
if nargin==0, path=fullfile(eco_project_root(),'config','AMP_H570_requirements.json'); end
J=jsondecode(fileread(path)); c=J.hybrid; power=AMPH570Powertrain(c); o=ttpa_disciplines();
segments=json_as_struct_array(J.segments);
r.aircraft="Conceptual Eco Caravan EX Amphibian / AMP-H570";
r.powerplant="AMP-H570 combustion/electric replacement";
r.removed_PT6_installed_mass_lb=c.removed_PT6_installed_mass_lb_assumed;
r.replacement_powerplant_dry_mass_lb=c.powerplant_dry_mass_lb_assumed;
r.hybrid_empty_lb=o.wts.OEW(9062)+power.mass_lb;
r.battery_mass_lb=power.battery_mass_lb; r.motor_mass_lb=power.motor_mass_lb;
r.added_system_mass_lb=power.mass_lb; r.payload_lb=c.payload_lb;
r.initial_weight_lb=r.hybrid_empty_lb+c.payload_lb+c.fuel_loaded_lb;
r.mtow_margin_lb=9062-r.initial_weight_lb; r.tank_margin_lb=2246-c.fuel_loaded_lb;
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
                D=q*o.geom.S_ref*(polar.CD0+polar.K1*CL^2);
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
            a=power.step(P,st,mode,fraction,dt/3600,o.prop,fuel);
            assert(fuel>=a.fuel_lb,'Hybrid:FuelDepleted','Selected schedule exhausted loaded fuel.');
            fuel=fuel-a.fuel_lb; W=W-a.fuel_lb; elapsed=elapsed+dt;
            r.trace.time_min(end+1)=elapsed/60; r.trace.soc(end+1)=power.get_soc();
            r.trace.weight_lb(end+1)=W; r.trace.fuel_remaining_lb(end+1)=fuel;
            r.trace.shaft_hp(end+1)=P; r.trace.combustion_hp(end+1)=a.combustion_hp; r.trace.generator_shaft_kW(end+1)=a.generator_shaft_kW;
            r.trace.electric_shaft_kW(end+1)=a.electric_shaft_kW;
            r.trace.battery_kW(end+1)=a.battery_kW; r.trace.segment_index(end+1)=k;
            maxP=max(maxP,P); if isfinite(CL), maxCL=max(maxCL,CL); end
        end
        row=struct('name',string(s.name),'mode',mode,'duration_min',duration/60, ...
            'fuel_lb',startFuel-fuel,'battery_kWh',startE-power.energy_kWh, ...
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
r.battery_used_kWh=(c.initial_soc-r.final_soc)*c.battery_capacity_kWh;
r.final_weight_lb=r.trace.weight_lb(end);
r.mass_balance_error_lb=r.initial_weight_lb-r.final_weight_lb-r.fuel_used_lb;
r.battery_reserve_kWh=c.battery_capacity_kWh*c.minimum_soc;
r.battery_energy_margin_kWh=r.final_soc*c.battery_capacity_kWh-r.battery_reserve_kWh;
r.completed_segments=numel(r.segments);
r.battery_discharged_kWh=sum(max(r.trace.battery_kW(2:end),0).*diff(r.trace.time_min)/60);
r.battery_recharged_kWh=-sum(min(r.trace.battery_kW(2:end),0).*diff(r.trace.time_min)/60);
r.battery_energy_balance_error_kWh=r.battery_used_kWh-r.battery_discharged_kWh+r.battery_recharged_kWh;
end
