function [result,hist]=run_concept2_study(varargin)
%RUN_CONCEPT2_STUDY Reproducible, explicitly assumed hybrid feasibility study.
% Default evaluates the JSON starting aircraft; 'sizing',true additionally
% attempts weight closure over candidate wing areas. 'sensitivities',true
% evaluates each one-factor assumption case at the same trial weight/area.
% Always reports hardware/certification gaps separately from numerical pass.
    root=setup_concept2();
    p=inputParser;
    p.addParameter('sizing',false,@islogical);
    p.addParameter('sensitivities',false,@islogical);
    p.addParameter('overrides',struct(),@isstruct);
    p.addParameter('engine',"",@(x)ischar(x)||isstring(x));
    p.addParameter('plot',true,@islogical);
    p.addParameter('plot_visible',false,@islogical);
    p.addParameter('output_dir',fullfile(root,'Results','Current'), ...
        @(x)ischar(x)||isstring(x));
    p.parse(varargin{:}); A=p.Results;
    [obj,opts,cfg,J]=build_concept2_study(A.overrides,string(A.engine));
    W=opts.W0; WS=W/obj.geom.S_ref;
    baselineW=W; baselineWS=WS;
    b=sizing_pass(obj,W,WS,opts.contexts,opts.energy_model);
    result=struct('status',b.status,'study_only',true,'hardware_verified',false, ...
        'constraint_mission_status',b.status, ...
        'certification_compliance_established',false,'W_TO',W,'assumptions',cfg, ...
        'assessment',b,'unresolved_items',unresolved());
    result.engine_id=string(A.engine);
    if strlength(result.engine_id)==0, result.engine_id=string(J.propulsion.selected_engine); end
    hist=struct([]);
    if A.sizing
        [hist,converged,state]=sizing_mainloop(obj,opts);
        result.sizing=state; result.sizing.converged=converged;
        result.baseline_assessment=b;
        result.baseline_W_TO=baselineW;
        if converged
            W=state.W0;
            a=struct('WS',W/state.S0,'ratings',state.ratings,'mission',state.mission, ...
                'report',state.constraints,'OEW_breakdown',state.OEW_breakdown);
            b=struct('status',"pass",'WS',a.WS,'ratings',a.ratings,'mission',a.mission, ...
                'report',a.report,'OEW_breakdown',a.OEW_breakdown,'last_assessment',a);
            result.assessment=b; result.W_TO=W;
            result.constraint_mission_status=b.status;
        end
        result.status="sizing: "+state.status;
    end
    if isfield(b,'last_assessment')
        a=b.last_assessment;
        if b.status=="pass", a=struct('WS',b.WS,'ratings',b.ratings, ...
                'mission',b.mission,'report',b.report,'OEW_breakdown',b.OEW_breakdown); end
        result.estimated_takeoff_mass_lb=obj.wts.payload()+a.OEW_breakdown.total+a.mission.fuel_lb;
        result.mass_closure_residual_lb=result.estimated_takeoff_mass_lb-W;
        result.team_mass_cap_met=result.estimated_takeoff_mass_lb<=cfg.team_mass_cap_lbf;
        result.mass_closed=isfield(result,'sizing') && result.sizing.converged;
        result.assessment_feasible=b.status=="pass";
        result.fuel_sizing_complete=all([a.mission.cases.completed]);
        result.motor_candidates=screen_motors(a.ratings,obj.prop.n_engines);
        result.pack_concept=screen_pack(a.mission.E_battery_nominal_kWh,cfg, ...
            max([a.mission.cases.max_battery_DC_kW]));
        if b.status=="pass" && abs(result.mass_closure_residual_lb)>opts.tol*W
            result.status="mission/constraints pass at trial weight; weight is not closed";
        end
        if isfield(result,'sizing')
            result.status="sizing: "+result.sizing.status;
        end
    end
    if A.sensitivities
        variations=cfg.sensitivities;
        if ~iscell(variations), variations=num2cell(variations); end
        rows=struct([]);
        for k=1:numel(variations)
            v=variations{k}; name=string(v.name); v=rmfield(v,'name');
            f=fieldnames(A.overrides);
            for j=1:numel(f), if ~isfield(v,f{j}), v.(f{j})=A.overrides.(f{j}); end; end
            [o,op]=build_concept2_study(v,string(A.engine));
            bb=sizing_pass(o,baselineW,baselineWS,op.contexts,op.energy_model);
            r=struct('name',name,'status',bb.status,'trial_weight_lb',baselineW,'pack_kWh',NaN, ...
                'fuel_lb',NaN,'estimated_takeoff_mass_lb',NaN,'reason',"");
            if isfield(bb,'last_assessment')
                aa=bb.last_assessment;
                r.pack_kWh=aa.mission.E_battery_nominal_kWh; r.fuel_lb=aa.mission.fuel_lb;
                r.estimated_takeoff_mass_lb=o.wts.payload()+aa.OEW_breakdown.total+r.fuel_lb;
                r.reason=strjoin(aa.mission.reasons,'; ');
            end
            if isempty(rows), rows=r; else, rows(end+1)=r; end %#ok<AGROW>
            fprintf('Sensitivity %s: %s\n',name,bb.status);
        end
        result.sensitivities=rows;
    end
    result.geometry_validation=concept2_geometry_validation(obj,W);
    if ~result.geometry_validation.intact_buoyancy_met
        result.status="fixed OpenVSP float volume below required intact buoyancy";
        fprintf('Float volume FAIL: %.2f ft3 available; %.2f ft3 required at %.0f lb.\n', ...
            result.geometry_validation.float_volume_available_ft3, ...
            result.geometry_validation.float_volume_required_ft3,W);
    end
    result=label_concept2_sensitivities(result);
    result.audit_model_version="2026-11-11";
    out=char(A.output_dir);
    if ~isfolder(out), mkdir(out); end
    result.comparison=concept2_comparison_metrics(result,J);
    if ~isempty(result.comparison)
        writetable(struct2table(result.comparison),fullfile(out,'comparison_metrics.csv'));
    end
    if A.plot && isfield(b,'last_assessment')
        result.constraint_plot_files=plot_concept2_constraints(result, ...
            'visible',A.plot_visible,'output_dir',out);
    end
    save(fullfile(out,'concept2_study.mat'),'result','hist');
    write_json(fullfile(out,'concept2_study.json'),result);
    if isfield(result,'sensitivities')
        writetable(struct2table(result.sensitivities),fullfile(out,'sensitivities.csv'));
    end
    if isfield(b,'last_assessment')
        a=b.last_assessment; m=a.mission;
        writetable(struct2table(a.report),fullfile(out,'constraint_margins.csv'));
        summary=rmfield(m.cases,'trace');
        % Variable-length leg-end arrays are retained in JSON/MAT; flatten
        % the scalar results for a spreadsheet-friendly scenario report.
        summary=rmfield(summary,'leg_end_soc');
        writetable(struct2table(summary),fullfile(out,'mission_cases.csv'));
        for k=1:numel(m.cases)
            if ~isempty(m.cases(k).trace)
                writetable(struct2table(m.cases(k).trace),fullfile(out,char(m.cases(k).name+"_trace.csv")));
            end
        end
        if A.plot, plot_soc(m,obj.prop.hybrid,out); end
        disp(struct2table(summary));
        fprintf('Pack search result %.2f kWh; loaded fuel %.1f lb.\n',m.E_battery_nominal_kWh,m.fuel_lb);
        if ~m.capacity_bracketed
            fprintf('Pack value is a FAILED SEARCH BOUND, not a feasible installed capacity.\n');
        end
        fprintf('Evaluated mass budget: %.1f lb at %.1f lb evaluated weight (mass_closed=%d).\n', ...
            result.estimated_takeoff_mass_lb,W,result.mass_closed);
        for reason=m.reasons, fprintf('  %s\n',reason); end
    end
    fprintf('Result: %s. PRELIMINARY ASSUMPTIONS; hardware validation remains open.\n',result.status);
    fprintf('Reports: %s\n',out);
end

function plot_soc(m,H,out)
    fig=figure('Visible','off','Position',[100,100,1000,700],'Color','w');
    done=onCleanup(@() close(fig));
    tiledlayout(2,1,'TileSpacing','compact');
    selected=["go_around_reserve","repeated_78"];
    for j=1:2
        nexttile;
        k=find(string({m.cases.name})==selected(j),1);
        if isempty(k) || isempty(m.cases(k).trace), continue; end
        t=m.cases(k).trace;
        plot([0,t.time_min],[t(1).soc_start,t.soc_end],'LineWidth',1.6);
        hold on; yline(H.battery_soc_min,'--r','SOC minimum');
        yline(H.battery_soc_max,':k','SOC maximum');
        ylim([0,1]); grid on;
        ylabel('State of charge'); xlabel('Elapsed time [min]');
        title(strrep(selected(j),'_',' '));
    end
    sgtitle('Preliminary study assumptions: reserve and repeated-leg SOC');
    exportgraphics(fig,fullfile(out,'soc_profiles.png'),'Resolution',140);
end

function pack=screen_pack(E,cfg,Pdc)
    np=round(E*1000/(cfg.cell_series_count*cfg.cell_nominal_energy_Wh));
    vmin=cfg.cell_series_count*cfg.cell_operating_min_voltage;
    vmax=cfg.cell_series_count*cfg.cell_max_voltage;
    pack=struct('series_cells',cfg.cell_series_count,'parallel_cells_total',np, ...
        'independent_strings',cfg.battery_string_count, ...
        'cell_count',cfg.cell_series_count*np,'nominal_energy_kWh',E, ...
        'minimum_operating_voltage',vmin,'maximum_voltage',vmax, ...
        'cell_mass_kg',cfg.cell_series_count*np*cfg.cell_mass_kg, ...
        'pack_mass_kg',E*1000/cfg.battery_specific_energy_Wh_kg, ...
        'max_current_A_at_voltage_floor',Pdc*1000/vmin, ...
        'max_cell_current_A_at_voltage_floor',Pdc*1000/(vmin*np), ...
        'magni650_voltage_range_screen',vmin>=500 && vmax<=850, ...
        'magniDrive100_voltage_range_screen',vmin>=550 && vmax<=800, ...
        'thermal_and_installation_verified',false);
end

function candidates=screen_motors(r,n)
% Nameplate screening only; RPM, peak duration, mass boundary, cooling,
% generating operation and hybrid installation still require supplier data.
    names=["magni350","magni650"];
    peak=[350,700]; cont=[165,515]; kg=[92.3,144];
    for k=1:2
        candidates(k)=struct('name',names(k),'peak_kW_each',peak(k), ...
            'continuous_kW_each',cont(k),'dry_mass_kg_each',kg(k), ...
            'required_peak_kW_each',r.P_motor_peak*.7457/n, ...
            'required_continuous_kW_each',r.P_motor_continuous*.7457/n, ...
            'rating_screen_pass',r.P_motor_peak*.7457/n<=peak(k) && ...
                r.P_motor_continuous*.7457/n<=cont(k), ...
            'installation_verified',false); %#ok<AGROW>
    end
end
function items=unresolved()
    items=["GE approved restart envelope/time, installed losses, fuel/idle maps", ...
        "pack-level thermal/current/charge and aging validation", ...
        "motor/inverter peak duration, generation and mass boundaries", ...
        "custom hybrid gearbox/clutch torque, loss and failure validation", ...
        "selected equipment electrical load budget", ...
        "selected propeller feathered drag and transition time", ...
        "accepted certification basis, critical-loss definition and full FMEA", ...
        "water takeoff/landing and hump calibration", ...
        "CG envelope, yaw stability, rudder authority and critical-failure Vmc", ...
        "20-KTAS land/water crosswind handling at OEW and all-speed water yaw control", ...
        "40-KTAS gust hydrostatic stability and tail/float installation loads"];
end
function write_json(path,value)
    fid=fopen(path,'w');
    if fid<0, error('run_concept2_study:Output','Cannot open %s.',path); end
    done=onCleanup(@() fclose(fid));
    fwrite(fid,jsonencode(value,PrettyPrint=true),'char');
end
