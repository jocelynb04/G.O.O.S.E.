function best = sizing_pass(obj,W_TO,WS_sweep,contexts,energy_model)
%SIZING_PASS Enumerate wings; independently size electric hardware.
% Fixed catalog turbines are never scaled. energy_model is a mission/SOC
% sizing callback: m=energy_model(obj,W_TO,demands,contexts). It must supply
% fuel_lb, E_battery_nominal_kWh, contexts, mission_feasible and
% failure_checks_complete. The latter covers pending additional failure
% cases in the JSON, including the still-unspecified electric departure OEI
% target. It must not be asserted from power constraints alone.
% Objective: minimum (OEW + mission fuel) at the trial W_TO, among the
% explicitly sampled wing areas. This is a discrete search, not a claimed
% global optimum. Each area rebuilds float/wing geometry and drag live.
    if isempty(obj.prop.reference_engine)
        error('sizing_pass:CatalogRequired', ...
            'This solver selects fixed catalog hardware; supply a catalog engine.');
    end
    if ~isa(energy_model,'function_handle')
        error('sizing_pass:MissionModelRequired', ...
            'Supply a mission/SOC sizing callback; the legacy fuel-only mission is insufficient.');
    end
    if ~iscell(contexts) || numel(contexts) ~= numel(obj.cons)
        error('sizing_pass:ContextsRequired','One context cell per condition is required.');
    end
    best = struct('status',"no feasible candidate",'objective_lb',Inf, ...
        'candidates',[]);
    original = capture(obj);
    restore = onCleanup(@() install(obj,original));
    for j=1:numel(WS_sweep)
        WS=WS_sweep(j);
        validateattributes(WS,{'numeric'},{'scalar','real','finite','positive'});
        obj.geom.W_TO=W_TO; obj.geom.S_ref=W_TO/WS;
        obj.wts.W_TO=W_TO;
        peak=0; continuous=0; inverter_need=0; candidate_ok=true;
        demands=cell(1,numel(obj.cons));
        for k=1:numel(obj.cons)
            d=constraint_demand(WS,obj,k); demands{k}=d; c=d.condition;
            if c.type == "landing"
                candidate_ok=candidate_ok && WS<=d.WS_wall;
                continue;
            end
            x=contexts{k};
            % Get ONLY turbine availability to find the motor residual.
            % Battery/inverter limits are checked after the mission callback
            % sizes them, rather than confusing a small initial guess with
            % an aerodynamic demand that needs a larger motor.
            tc=c; tc.power_source="turbine";
            if string(c.power_source)=="electric"
                x.turbines_running=false; x.turbine_survival_fraction=1;
                if c.oei, x.turbine_survival_fraction=0; end
                x.turbine_accessory_hp=0; x.turbine_charge_hp=0;
            end
            s=get_state(c.alt);
            if isfield(x,'oat_C'), s.oat_C=x.oat_C; end
            a=obj.prop.constraint_power_available(s,tc,x);
            required=W_TO*d.hp_per_lbf;
            candidate_ok=candidate_ok && isfinite(required) && required<=a.gearbox_limit_hp;
            residual=max(0,required-a.turbine_hp);
            if string(c.power_source)=="turbine"
                candidate_ok=candidate_ok && residual<=1e-8;
            else
                if ~any(string(c.power_source)==["electric","both"])
                    error('sizing_pass:SourceRequired','Invalid source for %s.',c.name);
                end
                if ~isfield(x,'motor_survival_fraction')
                    error('sizing_pass:FailureRequired','Declare motor survival fraction.');
                end
                f=x.motor_survival_fraction;
                validateattributes(f,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
                factor=f*c.power_setting*a.shaft_efficiency;
                if factor==0
                    need=0; candidate_ok=candidate_ok && residual<=1e-8;
                else
                    need=residual/factor;
                end
                if c.max_continuous, continuous=max(continuous,need);
                else, peak=max(peak,need); end
                % Surviving inverter throughput may be a tighter fraction
                % than surviving motors; size DC rating independently too.
                if ~isfield(x,'inverter_survival_fraction')
                    error('sizing_pass:FailureRequired','Declare inverter survival fraction.');
                end
                fi=x.inverter_survival_fraction;
                validateattributes(fi,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
                if fi==0
                    candidate_ok=candidate_ok && residual<=1e-8;
                else
                    H=obj.prop.hybrid;
                    inverter_need=max(inverter_need,residual*0.7457/ ...
                        (a.shaft_efficiency*fi*H.motor_efficiency*H.inverter_efficiency));
                end
            end
        end
        if ~candidate_ok
            best.candidates(j).status="airframe/turbine/gearbox fail";
            best.candidates(j).WS=WS;
            continue;
        end
        H=obj.prop.hybrid;
        ratio=H.motor_peak_over_continuous;
        validateattributes(ratio,{'numeric'},{'scalar','finite','>=',1});
        peak=max(peak,continuous);
        continuous=max(continuous,peak/ratio);
        obj.prop.P_motor_peak=peak;
        obj.prop.P_motor_continuous=continuous;
        % DC-side motor inverter throughput, upstream of ei*em. Dedicated
        % accessory loads bypass these propulsion inverters and remain in
        % the battery/mission power budget. Recharge may require more rating;
        % callback may return a larger P_inverter_rated_kW for generation.
        obj.prop.P_inverter_rated_kW=max(inverter_need, ...
            peak*0.7457/(H.motor_efficiency*H.inverter_efficiency));
        candidate=capture(obj);
        m=energy_model(obj,W_TO,demands,contexts);
        after=capture(obj);
        fixed={'S_ref','W_TO','P_motor_peak','P_motor_continuous','P_inverter_rated_kW'};
        for q=1:numel(fixed)
            if ~isequal(candidate.(fixed{q}),after.(fixed{q}))
                error('sizing_pass:MissionChangedCandidate', ...
                    'Mission callback changed %s; return energy outputs without resizing the candidate.',fixed{q});
            end
        end
        obj.prop.check_catalog_ratings();
        validateattributes(m.fuel_lb,{'numeric'},{'scalar','finite','nonnegative'});
        validateattributes(m.E_battery_nominal_kWh,{'numeric'},{'scalar','finite','positive'});
        obj.wts.E_battery_nominal_kWh=m.E_battery_nominal_kWh;
        if isfield(m,'P_inverter_rated_kW')
            validateattributes(m.P_inverter_rated_kW,{'numeric'}, ...
                {'scalar','finite','>=',obj.prop.P_inverter_rated_kW});
            obj.prop.P_inverter_rated_kW=m.P_inverter_rated_kW;
        end
        % The installed pack is the weight model's single source of truth.
        % Do not let callback contexts claim a different battery capacity.
        for k=1:numel(m.contexts)
            m.contexts{k}.E_battery_nominal_kWh=m.E_battery_nominal_kWh;
        end
        report=evaluate_source_constraints(WS,obj,W_TO,m.contexts);
        % Retain an actual failed assessment as well as successful winners.
        % Otherwise a missing recharge/mission margin disappears behind the
        % generic "no feasible candidate" result and cannot be reviewed.
        best.last_assessment=struct('WS',WS,'ratings',capture(obj), ...
            'report',report,'mission',m,'OEW_breakdown',obj.wts.OEW_breakdown(W_TO));
        best.candidates(j).WS=WS;
        if isfield(m,'reasons'), best.candidates(j).reason=strjoin(m.reasons,'; '); end
        geometry=concept2_geometry_validation(obj,W_TO);
        ok=geometry.intact_buoyancy_met && all(string({report.status})=="pass") && ...
            isequal(m.mission_feasible,true) && isequal(m.failure_checks_complete,true);
        best.candidates(j).status="mission/source/failure unresolved or fail";
        if ~geometry.intact_buoyancy_met
            best.candidates(j).status="fixed OpenVSP float buoyancy fail";
            best.candidates(j).reason="Imported enclosed float volume is below the required intact buoyancy.";
        end
        if ~ok, continue; end
        bd=obj.wts.OEW_breakdown(W_TO);
        objective=bd.total+m.fuel_lb;
        best.candidates(j).status="pass";
        if objective<best.objective_lb
            best.status="pass"; best.objective_lb=objective;
            best.WS=WS; best.S_ref=obj.geom.S_ref; best.ratings=capture(obj);
            best.report=report; best.mission=m; best.OEW_breakdown=bd;
        end
    end
    if best.status=="pass"
        % Public assessment must describe the winner, not the last grid point.
        best.last_assessment=struct('WS',best.WS,'ratings',best.ratings, ...
            'report',best.report,'mission',best.mission,'OEW_breakdown',best.OEW_breakdown);
    end
    % Enumeration has no lasting mutation; the caller installs the winner.
end

function s=capture(obj)
    s=struct('S_ref',obj.geom.S_ref,'W_TO',obj.geom.W_TO,'weights_W_TO',obj.wts.W_TO, ...
        'P_turbine_TO',obj.prop.P_turbine_TO, ...
        'P_turbine_continuous',obj.prop.P_turbine_continuous, ...
        'P_motor_peak',obj.prop.P_motor_peak, ...
        'P_motor_continuous',obj.prop.P_motor_continuous, ...
        'P_inverter_rated_kW',obj.prop.P_inverter_rated_kW, ...
        'E_battery_nominal_kWh',obj.wts.E_battery_nominal_kWh);
end
function install(obj,s)
    obj.geom.S_ref=s.S_ref; obj.geom.W_TO=s.W_TO;
    obj.wts.W_TO=s.weights_W_TO;
    obj.prop.P_turbine_TO=s.P_turbine_TO;
    obj.prop.P_turbine_continuous=s.P_turbine_continuous;
    obj.prop.P_motor_peak=s.P_motor_peak;
    obj.prop.P_motor_continuous=s.P_motor_continuous;
    obj.prop.P_inverter_rated_kW=s.P_inverter_rated_kW;
    obj.wts.E_battery_nominal_kWh=s.E_battery_nominal_kWh;
end
