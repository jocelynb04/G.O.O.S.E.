classdef Concept4Mission < handle
    properties
        J
        geom
        aero
        prop
        assumptions
    end
    methods
        function obj = Concept4Mission(J,geom,aero,prop,assumptions)
            obj.J = J;
            obj.geom = geom;
            obj.aero = aero;
            obj.prop = prop;
            obj.assumptions = assumptions;
        end
        function plan = plan(obj,mission_name,options)
            %plan - Inspect route phases and missing inputs without simulation.
            if nargin < 2 || isempty(mission_name), mission_name = 'std_mission'; end
            if nargin < 3, options = struct(); end
            plan = c4_mission_route(obj.J,obj.assumptions,mission_name,options);
        end
        function result = run(obj,takeoff_weight_lb,mission_name,sizing_probe,options)
            %run - Account for route fuel and energy without writing files.
            %   R = run(OBJ,W,NAME,PROBE,OPTIONS) accepts the same surface
            %   options as plan. Missing land energy inputs stop execution.
            %   Omitted options preserve the water-to-water baseline.
            if nargin < 3 || isempty(mission_name), mission_name = 'std_mission'; end
            if nargin < 4 || isempty(sizing_probe), sizing_probe = false; end
            if nargin < 5, options = struct(); end
            route = obj.plan(mission_name,options);
            if ~route.ready_for_energy_calculation
                error('C4:MissingSurfaceInputs', ...
                    'Missing land energy inputs: %s. Inspect mission.plan first.', ...
                    strjoin(route.missing_inputs,', '));
            end
            if ~isfield(obj.J.missions,mission_name)
                error('C4:Mission','Unknown mission name.');
            end
            profile = obj.J.missions.(mission_name);
            s = struct('W',takeoff_weight_lb,'soc',obj.prop.battery_initial_soc, ...
                'alt',0,'total_fuel',0,'cume',0,'peak_deficit',0, ...
                'peak_discharge',0,'peak_charge',0,'rows',struct([]));
            old_capacity = obj.prop.battery_capacity_kwh;
            if sizing_probe
                obj.prop.battery_capacity_kwh = max(old_capacity,100000);
            end
            cleanup = onCleanup(@() obj.setBatteryCapacity(old_capacity));
            segments = route.segments;
            for j = 1:numel(segments)
                seg = segments{j};
                phase = char(seg.type);
                detail = seg.route_detail;
                name = c4_get(seg,'name',phase);
                target_alt = c4_get(seg,'alt_ft',s.alt);
                battery_target = c4_get(seg,'phi',[]);
                if any(strcmp(phase,{'taxi','takeoff','landing','water_maneuver','approach'}))
                    minutes = detail.duration_min;
                    rating = 'continuous';
                    if strcmp(phase,'takeoff'), rating = 'takeoff'; end
                    s = obj.accountSegment(s,phase,minutes/60,detail.shaft_hp,target_alt, ...
                        battery_target,NaN,name,rating,detail);
                    s.alt = target_alt;
                elseif any(strcmp(phase,{'climb','balked_landing'}))
                    if target_alt <= s.alt
                        error('C4:MissionInfeasible','Climb altitude must exceed starting altitude.');
                    end
                    n = c4_get(profile,'climb_segments',8);
                    if strcmp(phase,'balked_landing')
                        roc = obj.assumptions.balked_landing_climb_fpm;
                        cfg = detail.aero_config;
                        rating = 'takeoff';
                    else
                        roc = obj.assumptions.nominal_climb_fpm;
                        cfg = 'clean';
                        rating = 'continuous';
                    end
                    start_alt = s.alt;
                    dh = (target_alt-start_alt)/n;
                    for i = 1:n
                        mid = start_alt+(i-0.5)*dh;
                        best = segment_climb_C4(s.W,mid,roc,obj.aero,obj.prop.eta_p_climb,cfg);
                        s = obj.accountSegment(s,phase,dh/roc/60,best.shaft_hp,mid, ...
                            battery_target,best.ktas,sprintf('%s [%d/%d]',name,i,n),rating,detail);
                    end
                    s.alt = target_alt;
                elseif any(strcmp(phase,{'cruise','loiter'}))
                    speed = seg.ktas;
                    if strcmp(phase,'cruise')
                        n = c4_get(profile,'cruise_segments',12);
                        total_hr = seg.distance_nm/speed;
                        eta = obj.prop.eta_p_cruise;
                    else
                        n = max(1,obj.assumptions.loiter_subsegments);
                        total_hr = seg.time_min/60;
                        eta = obj.prop.eta_p_loiter;
                    end
                    for i = 1:n
                        if strcmp(phase,'cruise')
                            required = segment_cruise_C4(s.W,speed,target_alt,obj.aero,eta);
                        else
                            required = segment_loiter_C4(s.W,speed,target_alt,obj.aero,eta);
                        end
                        s = obj.accountSegment(s,phase,total_hr/n,required.shaft_hp,target_alt, ...
                            battery_target,speed,sprintf('%s [%d/%d]',name,i,n),'continuous',detail);
                    end
                    s.alt = target_alt;
                elseif strcmp(phase,'descent')
                    s = obj.accountSegment(s,phase,obj.assumptions.descent_duration_min/60, ...
                        0,target_alt,battery_target,NaN,name,'continuous',detail);
                    s.alt = target_alt;
                else
                    error('C4:Mission','Unsupported mission phase: %s',phase);
                end
            end
            usable = obj.prop.battery_initial_soc-obj.prop.battery_min_soc;
            if usable <= 0, error('C4:SOC','Invalid usable battery SOC.'); end
            if sizing_probe, status = 'ENERGY_SIZING_PROBE_ONLY';
            else, status = 'INTEGRATED_MISSION_RUN_UNVERIFIED_ASSUMPTIONS'; end
            result = struct('status',status,'mission_name',mission_name, ...
                'gross_weight_start_lb',takeoff_weight_lb,'total_fuel_lb',s.total_fuel, ...
                'weight_end_lb',s.W,'soc_end',s.soc, ...
                'peak_cumulative_pack_deficit_kwh',s.peak_deficit, ...
                'minimum_battery_capacity_kwh_for_soc_window',s.peak_deficit/usable, ...
                'peak_battery_discharge_bus_kw',s.peak_discharge, ...
                'peak_battery_charge_bus_kw',s.peak_charge,'segments',s.rows, ...
                'notes',{{'Ground phase power and time unverified', ...
                'Water hump drag not modeled','Constant BSFC not a validated turboshaft map'}});
            result.route = route;
            result.notes = [result.notes route.limitations];
            clear cleanup;
        end
        function s = accountSegment(obj,s,phase,duration_hr,power_hp,alt_ft,target,speed,name,rating,detail)
            if nargin < 11
                detail = struct('power_phase',phase,'phase_name',phase, ...
                    'surface','unspecified','aero_config','unspecified', ...
                    'power_mode','unspecified', ...
                    'generator_intended_state','unspecified', ...
                    'input_status','UNSPECIFIED');
            end
            if isempty(target), target = obj.prop.get_phi(detail.power_phase); end
            if strcmp(detail.power_mode,'electric_only'), target = 1; end
            try
                p = obj.prop.power_balance(power_hp,duration_hr,alt_ft,detail.power_phase,s.soc,target,0,0,rating);
            catch ME
                error('C4:MissionInfeasible','%s: %s (W=%.1f, SOC=%.4f, power=%.1f hp)', ...
                    name,ME.message,s.W,s.soc,power_hp);
            end
            s.soc = p.soc_end;
            s.W = s.W-p.fuel_burn_lb;
            if s.W <= 0
                error('C4:MissionInfeasible','Mission fuel burn exceeds gross weight.');
            end
            s.total_fuel = s.total_fuel+p.fuel_burn_lb;
            s.cume = s.cume+p.pack_energy_change_kwh;
            s.peak_deficit = max(s.peak_deficit,s.cume);
            s.peak_discharge = max(s.peak_discharge,p.battery_bus_kw);
            s.peak_charge = max(s.peak_charge,-p.battery_bus_kw);
            row = struct('name',name,'phase',phase,'altitude_ft',alt_ft, ...
                'speed_ktas',speed,'duration_min',duration_hr*60, ...
                'shaft_power_hp',power_hp,'fuel_burn_lb',p.fuel_burn_lb, ...
                'weight_end_lb',s.W,'soc_start',p.soc_start,'soc_end',p.soc_end, ...
                'battery_bus_kw',p.battery_bus_kw,'generator_bus_kw',p.generator_bus_kw, ...
                'pack_energy_change_kwh',p.pack_energy_change_kwh, ...
                'battery_deficit_from_initial_kwh',s.cume,'electric_only',p.electric_only);
            row.phase_name = detail.phase_name;
            row.surface = detail.surface;
            row.aero_config = detail.aero_config;
            row.power_mode = detail.power_mode;
            row.input_status = detail.input_status;
            row.generator_intended_state = detail.generator_intended_state;
            row.generator_physical_state = 'NOT_MODELED';
            row.generator_previous_intent = c4_get(s,'generator_intent','unspecified');
            row.generator_intent_changed = ...
                ~strcmp(row.generator_previous_intent,detail.generator_intended_state);
            row.generator_electrical_output_zero = p.generator_bus_kw == 0;
            s.generator_intent = detail.generator_intended_state;
            if isempty(s.rows), s.rows = row; else, s.rows(end+1) = row; end
        end
        function setBatteryCapacity(obj,v)
            obj.prop.battery_capacity_kwh = v;
        end
    end
end
