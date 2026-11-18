function data=source_constraint_diagram_data(obj,W_TO,contexts,WS,span_limit)
%SOURCE_CONSTRAINT_DIAGRAM_DATA Geometry-aware, fixed-operating-context sweep.
% Motor panel: true conditional W/P_peak limits, holding turbines, pack,
% inverter, SOC, duration and peak/continuous ratio fixed. Battery/inverter
% and gearbox ceilings must pass even at unlimited motor nameplate power.
% Turbine panel: required TO-rating equivalents using the selected engine's
% local rating/map ratio. Catalog engines are NEVER resized or mutated;
% only their actual fixed-rating horizontal line is a hardware prediction.
% Margin panel: actual fixed-installation available/required shaft power.
% Mission SOC and weight closure are not recomputed across this diagram.
    validateattributes(W_TO,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(WS,{'numeric'},{'vector','real','finite','positive','nonempty'});
    validateattributes(span_limit,{'numeric'},{'scalar','real','positive'});
    if ~iscell(contexts) || numel(contexts)~=numel(obj.cons)
        error('source_constraint_diagram_data:Contexts','Supply one context per condition.');
    end
    validateattributes(obj.prop.P_motor_peak,{'numeric'},{'scalar','finite','positive'});
    validateattributes(obj.prop.P_motor_continuous,{'numeric'},{'scalar','finite','positive'});
    originalS=obj.geom.S_ref; originalW=obj.geom.W_TO;
    done=onCleanup(@() restore_geometry(obj,originalS,originalW));
    WS=unique(reshape(WS,1,[])); n=numel(obj.cons); m=numel(WS);
    motor=NaN(n,m); turbine=motor; required=motor; available=motor;
    margin=motor; status=repmat("unresolved",n,m); reasons=strings(n,m);
    names=strings(n,1); sources=names; types=names;
    motorCases=false(n,1); turbineCases=motorCases;
    motorHardOK=true(1,m); turbineFixedElectricOK=true(1,m);
    pending=false(1,m);
    walls=NaN(1,n);
    for k=1:n
        c=get_con(k,obj.cons); names(k)=c.name; types(k)=c.type;
        sources(k)=string(c.power_source);
        if c.type=="landing", walls(k)=constraint_landing(obj,k); continue; end
        motorCases(k)=any(sources(k)==["electric","both"]);
        turbineCases(k)=any(sources(k)==["turbine","both"]);
    end
    wall=Inf; if any(isfinite(walls)), wall=min(walls(isfinite(walls))); end
    ratio=obj.prop.P_motor_continuous/obj.prop.P_motor_peak;
    for j=1:m
        obj.geom.W_TO=W_TO; obj.geom.S_ref=W_TO/WS(j);
        report=evaluate_source_constraints(WS(j),obj,W_TO,contexts);
        for k=1:n
            r=report(k); c=get_con(k,obj.cons);
            required(k,j)=r.required_hp; available(k,j)=r.available_hp;
            status(k,j)=r.status; reasons(k,j)=r.reason;
            if c.type=="landing", continue; end
            margin(k,j)=r.available_hp/r.required_hp;
            s=get_state(c.alt);
            if isfield(contexts{k},'oat_C'), s.oat_C=contexts{k}.oat_C; end
            if r.status=="unresolved"
                motorHardOK(j)=false; turbineFixedElectricOK(j)=false;
                continue;
            end
            % Duration/auxiliary overload failures have no usable source
            % solution; a zero boundary is distinct from missing data (NaN).
            if ~isfinite(r.available_hp)
                motor(k,j)=0; turbine(k,j)=0;
                motorHardOK(j)=false; turbineFixedElectricOK(j)=false;
                continue;
            end
            a=obj.prop.constraint_power_available(s,c,contexts{k});
            req=r.required_hp;
            if motorCases(k)
                need=max(0,req-a.turbine_hp);
                ratingFraction=1; if c.max_continuous, ratingFraction=ratio; end
                coefficient=a.shaft_efficiency*c.power_setting* ...
                    contexts{k}.motor_survival_fraction*ratingFraction;
                hard=req<=a.gearbox_limit_hp+1e-8 && need<=a.motor_nonrating_hp+1e-8;
                motorHardOK(j)=motorHardOK(j) && hard;
                if ~hard || (coefficient==0 && need>1e-8)
                    motor(k,j)=0;
                elseif need<=1e-8
                    motor(k,j)=Inf;
                else
                    motor(k,j)=W_TO*coefficient/need;
                end
            else
                motorHardOK(j)=motorHardOK(j) && r.status=="pass";
            end
            if turbineCases(k)
                x=contexts{k};
                rating="takeoff"; if c.max_continuous, rating="max_continuous"; end
                coefficient=a.shaft_efficiency*c.power_setting*x.turbine_survival_fraction ...
                    *double(x.turbines_running)* ...
                    obj.prop.turbine_power_available(s,rating)/obj.prop.P_turbine_TO;
                loadhp=a.shaft_efficiency*(x.turbine_accessory_hp+x.turbine_charge_hp);
                need=max(0,req-a.motor_hp)+loadhp;
                if req>a.gearbox_limit_hp+1e-8 || (coefficient==0 && need>1e-8)
                    turbine(k,j)=0;
                elseif need<=1e-8
                    turbine(k,j)=Inf;
                else
                    turbine(k,j)=W_TO*coefficient/need;
                end
            else
                turbineFixedElectricOK(j)=turbineFixedElectricOK(j) && r.status=="pass";
            end
        end
        % Pending failure requirements must not disappear from shading.
        if numel(report)>n
            pending(j)=true;
            motorHardOK(j)=false; turbineFixedElectricOK(j)=false;
        end
    end
    spanWall=W_TO*obj.geom.AR/span_limit^2;
    geometryOK=WS<=wall & WS>spanWall & obj.geom.intact_buoyancy_met; % study span limit is strict
    motorEnvelope=min(motor(motorCases,:),[],1);
    turbineEnvelope=min(turbine(turbineCases,:),[],1);
    power=types~="landing";
    envelope=min(margin(power,:),[],1);
    unknown=any(status(power,:)=="unresolved",1) | pending;
    envelope(unknown)=NaN;
    motorEnvelope(any(isnan(motor(motorCases,:)),1))=NaN;
    turbineEnvelope(any(isnan(turbine(turbineCases,:)),1))=NaN;
    data=struct('WS',WS,'W_TO',W_TO,'names',names,'sources',sources,'types',types, ...
        'required_hp',required,'available_hp',available,'status',status,'reasons',reasons, ...
        'motor_cases',motorCases,'turbine_cases',turbineCases,'power_cases',power, ...
        'motor_WP_limits',motor,'turbine_WP_reference_limits',turbine, ...
        'motor_envelope',motorEnvelope,'turbine_reference_envelope',turbineEnvelope, ...
        'power_margin_ratio',margin,'margin_envelope',envelope, ...
        'unknown',unknown, ...
        'intact_buoyancy_met',obj.geom.intact_buoyancy_met, ...
        'float_volume_available_ft3',obj.geom.V_enclosed_total, ...
        'float_volume_required_ft3',obj.geom.V_required_enclosed_total, ...
        'motor_hard_limits_ok',motorHardOK,'turbine_fixed_electric_ok',turbineFixedElectricOK, ...
        'geometry_ok',geometryOK,'landing_WS_max',wall,'span_WS_min',spanWall, ...
        'motor_actual_WP',W_TO/obj.prop.P_motor_peak, ...
        'turbine_actual_WP',W_TO/obj.prop.P_turbine_TO, ...
        'current_installation_pass',geometryOK & ~unknown & all(status(power,:)=="pass",1));
end
function restore_geometry(obj,S,W)
    obj.geom.S_ref=S; obj.geom.W_TO=W;
end
