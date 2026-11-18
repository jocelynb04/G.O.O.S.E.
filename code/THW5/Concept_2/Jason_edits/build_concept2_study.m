function [obj,opts,cfg,J] = build_concept2_study(overrides,engine_id)
%BUILD_CONCEPT2_STUDY Explicit, isolated preliminary design assumptions.
% Original requirements stay intact. This function applies a documented
% Level-3-low-speed study basis and proposed pack/installation limits in
% memory. None of the assumption fields constitutes manufacturer approval.
    if nargin<1, overrides=struct(); end
    if nargin<2, engine_id=""; end
    root=concept2_project_root();
    cfg=jsondecode(fileread(fullfile(root,'concept2_study_inputs.json')));
    fields=fieldnames(overrides);
    for k=1:numel(fields)
        if ~isfield(cfg,fields{k})
            error('build_concept2_study:UnknownOverride','Unknown study input: %s',fields{k});
        end
        cfg.(fields{k})=overrides.(fields{k});
    end
    validate_concept2_inputs(cfg);
    cfg.battery_voltage_power_factor=cfg.cell_operating_min_voltage/cfg.cell_nominal_voltage;
    J=jsondecode(fileread(ttpa_requirements_path()));
    obj=ttpa_disciplines();
    if engine_id~=""
        obj.prop=TtpaProp(ttpa_requirements_path(),engine_id);
        obj.geom=TtpaGeom(ttpa_requirements_path(),obj.prop);
        obj.aero=TtpaAero(ttpa_requirements_path(),obj.geom);
        obj.wts=TtpaWeights(ttpa_requirements_path(),obj.geom,obj.prop);
    end
    H=obj.prop.hybrid;
    H.battery_max_continuous_discharge_C=cfg.battery_continuous_C;
    H.battery_max_discharge_C=cfg.battery_peak_C;
    H.battery_max_charge_C=cfg.battery_charge_C;
    H.battery_specific_energy_WH_per_kg=cfg.battery_specific_energy_Wh_kg;
    % Public magni650 dry-mass/rating ratios guide a SCALABLE study mass
    % estimate, not an executable catalog motor or an approved mass boundary.
    H.motor_specific_power_kW_per_kg=700/144;
    H.motor_continuous_specific_power_kW_per_kg=515/144;
    obj.prop.hybrid=H;
    obj.aero.feathered_drag_area_ft2=cfg.feathered_drag_area_ft2_each;
    obj.geom.W_TO=J.sizing.W_TO_guess_lbf;
    obj.geom.S_ref=J.sizing.S_ref_guess_ft2;
    obj.wts.W_TO=obj.geom.W_TO;
    obj.wts.W_additional_powertrain=2.20462262185*cfg.additional_gearbox_mass_kg_per_kW ...
        *obj.prop.n_engines*cfg.gearbox_hp_each*0.7457;
    % Preserve inherited en-route OEI as an EXTRA study case, not a claim
    % that its homework gradient is the applicable Level-3 takeoff target.
    raw=J.constraints.conditions;
    if ~iscell(raw), raw=num2cell(raw); end
    for k=1:numel(raw)
        if string(raw{k}.name)=="Climb AEO", raw{k}.G=.04; end
        if string(raw{k}.name)=="Climb BL"
            raw{k}.config='landing_flaps_gear_down';
        end
    end
    failure=struct('name','Electric departure OEI','type','climb_gradient', ...
        'altitude_ft',400,'G',.01,'config','takeoff_flaps_gear_up', ...
        'oei',true,'propeller_stopped',true,'failed_propeller_state','feathered', ...
        'max_continuous',true,'beta',1,'power_setting',1,'power_source','electric');
    raw{end+1}=failure;
    for name=["Electric scheduled climb","Electric go-around rate"]
        c=struct('name',char(name),'type','climb_rate','altitude_ft',1500, ...
            'roc_fpm',cfg.electric_climb_fpm,'config','takeoff_flaps_gear_up', ...
            'oei',false,'max_continuous',true,'beta',1,'power_setting',1, ...
            'power_source','electric','speed_min_ktas',cfg.electric_climb_ktas, ...
            'speed_max_ktas',cfg.electric_climb_ktas);
        if contains(name,'go-around'), c.config='landing_flaps_gear_up'; end
        raw{end+1}=c; %#ok<AGROW>
    end
    raw{end+1}=struct('name','Electric restart hold','type','cruise_speed', ...
        'altitude_ft',1500,'ktas',cfg.electric_climb_ktas,'beta',1, ...
        'max_continuous',true,'method','drag_based','power_source','electric', ...
        'prop_efficiency_mode','climb');
    obj.cons=json_as_struct_array(raw);
    obj.additional_failure_checks=[]; % replaced by numerical study condition
    contexts=concept2_contexts(obj,cfg);
    wall=Inf;
    for k=1:numel(obj.cons)
        if string(obj.cons(k).type)=="landing", wall=min(wall,constraint_landing(obj,k)); end
    end
    sweep=unique([reshape(cfg.wing_loading_sweep_psf,1,[]),wall]);
    sweep=sweep(isfinite(sweep)&sweep<=wall);
    opts=struct('W0',obj.geom.W_TO,'WS_sweep',sweep, ...
        'tol',1e-4,'max_iter',80,'relax',.35,'contexts',{contexts}, ...
        'energy_model',@(o,w,d,x) hybrid_mission_energy(o,w,d,x,cfg,J));
end
