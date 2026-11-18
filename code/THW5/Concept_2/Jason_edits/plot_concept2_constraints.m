function [files,data,hybrid]=plot_concept2_constraints(result,varargin)
%PLOT_CONCEPT2_CONSTRAINTS Plot a trial aircraft even when weight cannot close.
%   plot_concept2_constraints() loads Results/Current/concept2_study.mat.
%   plot_concept2_constraints(result,'visible',false) exports without windows.
% Figures use actual source-specific demands, rebuild geometry at each W/S,
% and preserve fixed mission-derived SOC/duration/resource assumptions.
% Green areas are explicitly STATIC power/geometry checks, not a full mission
% or weight-closure result. See CONCEPT2_STUDY.md for axis interpretations.
    root=concept2_project_root();
    if nargin<1 || isempty(result)
        path=fullfile(root,'Results','Current','concept2_study.mat');
        if ~isfile(path)
            error('plot_concept2_constraints:RunStudyFirst', ...
                'Run run_concept2_study first, or pass an existing result.');
        end
        saved=load(path,'result'); result=saved.result;
        if ~isfield(result,'audit_model_version')
            error('plot_concept2_constraints:StaleResults', ...
                'Saved results predate the audit. Run run_concept2_study to regenerate them.');
        end
    end
    p=inputParser;
    p.addParameter('visible',true,@islogical);
    p.addParameter('output_dir',fullfile(root,'Results','Current'),@(x)ischar(x)||isstring(x));
    p.addParameter('wing_loading',linspace(15,50,241), ...
        @(x)isnumeric(x)&&isvector(x)&&all(isfinite(x))&&all(x>0));
    p.parse(varargin{:}); A=p.Results;
    [a,W,closed]=assessment(result);
    id=engine_id(result,a.ratings);
    [obj,~,cfg]=build_concept2_study(result.assumptions,id);
    r=a.ratings;
    obj.geom.W_TO=W; obj.geom.S_ref=r.S_ref;
    obj.prop.P_motor_peak=r.P_motor_peak;
    obj.prop.P_motor_continuous=r.P_motor_continuous;
    obj.prop.P_inverter_rated_kW=r.P_inverter_rated_kW;
    obj.wts.E_battery_nominal_kWh=r.E_battery_nominal_kWh;
    xs=a.mission.contexts;
    for k=1:numel(xs), xs{k}.E_battery_nominal_kWh=r.E_battery_nominal_kWh; end
    wall=Inf;
    for k=1:numel(obj.cons)
        if string(obj.cons(k).type)=="landing", wall=min(wall,constraint_landing(obj,k)); end
    end
    spanWall=W*obj.geom.AR/cfg.span_limit_ft^2;
    trialWS=W/r.S_ref; WS=reshape(A.wing_loading,1,[]);
    % Include the point and geometry boundaries exactly, plus points just
    % inside each boundary so shading does not lose the narrow feasible strip.
    extra=[trialWS,wall,wall*(1-1e-8),spanWall,spanWall*(1+1e-8)];
    extra=extra(isfinite(extra)&extra>=min(WS)&extra<=max(WS));
    WS=unique([WS,trialWS,extra]);
    data=source_constraint_diagram_data(obj,W,xs,WS,cfg.span_limit_ft);
    data.trial_WS=trialWS;
    data.metadata=struct('engine_id',id,'source_ratings',r,'weight_closed',closed, ...
        'SOC_policy',"mission-assessed condition SOC held fixed across wing sweep", ...
        'mission_recomputed_across_sweep',false,'static_checks_only',true);
    bound=isfield(a.mission,'capacity_bracketed') && ~a.mission.capacity_bracketed;
    data.metadata.capacity_is_failed_search_bound=bound;
    out=char(A.output_dir); if ~isfolder(out), mkdir(out); end
    files=struct('motor_png',fullfile(out,'motor_constraint_diagram.png'), ...
        'turbine_png',fullfile(out,'turbine_constraint_diagram.png'), ...
        'combined_png',fullfile(out,'combined_constraint_margins.png'), ...
        'matching_png',fullfile(out,'concept2_matching_diagram.png'), ...
        'matching_pdf',fullfile(out,'concept2_matching_diagram.pdf'), ...
        'hybrid_mat',fullfile(out,'hybrid_constraint_analysis.mat'), ...
        'hybrid_csv',fullfile(out,'hybrid_reference_power.csv'), ...
        'data_mat',fullfile(out,'constraint_diagram_data.mat'), ...
        'data_csv',fullfile(out,'constraint_diagram_data.csv'));
    colors=lines(numel(data.names));
    visible='off'; if A.visible, visible='on'; end
    ymax=power_axis_limit(data);
    [~,trial]=min(abs(data.WS-trialWS));
    annotationText=sprintf(['Trial aircraft: W = %.0f lb; S = %.1f sq ft; b = %.1f ft\n', ...
        'Turbines = %.0f hp TO; motor = %.0f / %.0f hp peak / continuous\n', ...
        'Battery = %.1f kWh; W/S = %.2f lb/sq ft'], ...
        W,r.S_ref,obj.geom.b,r.P_turbine_TO,r.P_motor_peak,r.P_motor_continuous, ...
        r.E_battery_nominal_kWh,trialWS);
    state="WEIGHT NOT CLOSED";
    if closed, state="Study weight closure converged"; end
    if bound, state=state+" | ELECTRICAL CAPACITY IS A FAILED SEARCH BOUND"; end
    footer=["Preliminary correlations and hardware assumptions | "+state, ...
        "SOC, duration, pack and inverter held fixed; mission/weight closure not recalculated across this sweep."];
    if any(data.unknown)
        footer(end+1)=sprintf('Unresolved inputs at %d/%d sweep points; those regions are not shaded.', ...
            sum(data.unknown),numel(data.WS));
    end

    % 1. A motor sizing slice is meaningful because motors are independently
    % sized. Hard electrical/gearbox limits can eliminate all motor ratings.
    fig=canvas(visible); ax=axes(fig,'Position',[.085,.14,.88,.74]); hold(ax,'on');
    mask=data.geometry_ok & data.motor_hard_limits_ok & ~data.unknown & ~bound;
    band(ax,data.WS,zeros(size(WS)),min(ymax,data.motor_envelope),mask,[.7,.9,.7], ...
        'Conditional static feasible region');
    curves(ax,data,data.motor_WP_limits,data.motor_cases,colors);
    plot(ax,data.WS,data.motor_envelope,'k-','LineWidth',2.3,'DisplayName','Motor-rating envelope');
    yline(ax,data.motor_actual_WP,'--','Color',[.42,.30,.16],'LineWidth',1.5, ...
        'DisplayName','Installed motor peak loading');
    design_point(ax,trialWS,data.motor_actual_WP,'Concept 2 design point');
    best_motor_point(ax,data,mask);
    finish_axes(ax,data,ymax,'Motor peak power loading W/P_{motor,peak} [lbf/hp]', ...
        'Concept 2 Motor Constraints');
    legend(ax,'Location','northeast','FontSize',8.5,'Interpreter','none');
    note(fig,annotationText,[footer, ...
        "Motor sizing holds peak/continuous ratio fixed. Zero boundary = hard source limit or stalled condition."]);
    export_plot(fig,files.motor_png,A.visible);

    % 2. Required turbine equivalents reference the selected engine map.
    % The ONLY hardware prediction is the actual catalog-loading line. Shade
    % a thin band on that line, rather than suggesting arbitrary GE resizing.
    fig=canvas(visible); ax=axes(fig,'Position',[.085,.14,.88,.74]); hold(ax,'on');
    mask=data.current_installation_pass & ~bound;
    band(ax,data.WS,repmat(.96*data.turbine_actual_WP,size(WS)), ...
        repmat(1.04*data.turbine_actual_WP,size(WS)),mask,[.7,.9,.7], ...
        'Selected installation passes static checks');
    curves(ax,data,data.turbine_WP_reference_limits,data.turbine_cases,colors);
    plot(ax,data.WS,data.turbine_reference_envelope,'k-','LineWidth',2.3, ...
        'DisplayName','Required-rating reference envelope');
    yline(ax,data.turbine_actual_WP,'--','Color',[.42,.30,.16],'LineWidth',1.5, ...
        'DisplayName','Fixed catalog turbine loading');
    design_point(ax,trialWS,data.turbine_actual_WP,'Concept 2 turbine installation');
    finish_axes(ax,data,ymax,'Turbine TO-reference power loading W_{TO}/P_{turbine,TO} [lb/hp]', ...
        'Concept 2 Turbine Matching Diagram');
    legend(ax,'Location','northeast','FontSize',8.5,'Interpreter','none');
    note(fig,annotationText,[footer, ...
        "Curves use the selected turbine map as a reference; GE engines are not resized."]);
    export_plot(fig,files.turbine_png,A.visible);

    % 3. An actual-installation ratio avoids mixing electric and turbine hp
    % into a fictitious universal P_SL. Every active curve must be >= 1.
    fig=canvas(visible); ax=axes(fig,'Position',[.085,.14,.88,.74]); hold(ax,'on');
    finite=data.power_margin_ratio(isfinite(data.power_margin_ratio));
    marginMax=4;
    if ~isempty(finite), marginMax=max(2,min(8,1.1*max(finite))); end
    band(ax,data.WS,ones(size(WS)),min(marginMax,data.margin_envelope), ...
        data.current_installation_pass & ~bound,[.7,.9,.7],'All static source checks pass');
    curves(ax,data,data.power_margin_ratio,data.power_cases,colors);
    plot(ax,data.WS,data.margin_envelope,'k-','LineWidth',2.5,'DisplayName','Minimum margin: all power cases');
    yline(ax,1,'--','Color',[.60,.16,.16],'LineWidth',1.6,'DisplayName','Required threshold = 1');
    design_point(ax,trialWS,data.margin_envelope(trial),'Concept 2 design point');
    finish_axes(ax,data,marginMax,'Available shaft power / required shaft power [-]', ...
        'Concept 2 Hybrid Power Margins');
    legend(ax,'Location','northeast','FontSize',8.5,'Interpreter','none');
    note(fig,annotationText,[footer, ...
        "Curves above 1 meet their power check; green also enforces landing and span limits."]);
    export_plot(fig,files.combined_png,A.visible);
    save(files.data_mat,'data');
    [i,j]=ndgrid(1:numel(data.names),1:numel(data.WS));
    rows=table(data.names(i(:)),data.sources(i(:)),reshape(data.WS(j(:)),[],1), ...
        data.required_hp(:),data.available_hp(:),data.power_margin_ratio(:), ...
        data.motor_WP_limits(:),data.turbine_WP_reference_limits(:),data.status(:), ...
        data.reasons(:),'VariableNames',{'Condition','Source','WS_lb_ft2','Required_hp', ...
        'Available_hp','Power_margin_ratio','Motor_WP_limit','Turbine_WP_reference_limit', ...
        'Status','Reason'});
    writetable(rows,files.data_csv);
    % Common peak-power basis used by the Caravan Hybrid_MultiEngine chart.
    % This normalization does not change any source-specific availability.
    takeoff=find(string({obj.cons.type})=="takeoff",1);
    assert(~isempty(takeoff),'Concept2:TakeoffContext','Takeoff context required.');
    c=get_con(takeoff,obj.cons);
    c.power_source="both"; c.max_continuous=false; c.oei=false; c.power_setting=1;
    x=xs{takeoff};
    x.turbines_running=true; x.soc=obj.prop.hybrid.battery_soc_max;
    x.motor_survival_fraction=1; x.turbine_survival_fraction=1;
    x.inverter_survival_fraction=1; x.battery_survival_fraction=1;
    x.gearbox_limit_hp=obj.prop.n_engines*cfg.gearbox_hp_each;
    x.duration_min=cfg.takeoff_min;
    % Charge is disabled for this maximum combined peak reference. Accessory
    % loads are assigned to the running turbines once, leaving pack power for boost.
    x.turbine_charge_hp=0;
    x.turbine_accessory_hp=sum([cfg.accessories.kW].*[cfg.accessories.duty])/(.7457*.90);
    x.accessory_dc_kW=0;
    peak=obj.prop.constraint_power_available(get_state(0),c,x);
    [mainFigure,hybrid]=plot_concept2_hybrid_constraints(data,peak.total_hp,A.visible);
    save(files.hybrid_mat,'hybrid');
    writetable(hybrid.reference_power,files.hybrid_csv);
    exportgraphics(mainFigure,files.matching_pdf,'ContentType','vector');
    export_plot(mainFigure,files.matching_png,A.visible);
    fprintf('Hybrid reference: W/S %.2f lbf/ft^2; W/P %.2f lbf/shp; %.1f shp net combined peak.\n', ...
        hybrid.reference.WS,hybrid.reference.WP,hybrid.reference.peak_shp);
    fprintf('Installed pair passes all static checks at trial wing area: %d.\n', ...
        hybrid.reference.passes_primary_screen);
    if A.visible, figure(mainFigure); end
    fprintf('Constraint diagrams: %s\n',out);
end

function [a,W,closed]=assessment(r)
    closed=isfield(r,'sizing') && isfield(r.sizing,'converged') && r.sizing.converged;
    if closed
        a=struct('ratings',r.sizing.ratings,'mission',r.sizing.mission);
        W=r.sizing.W0;
    elseif isfield(r,'assessment') && isfield(r.assessment,'last_assessment')
        a=r.assessment.last_assessment; W=r.W_TO;
    else
        error('plot_concept2_constraints:InstallationRequired', ...
            'No assessed installation is stored. Run run_concept2_study or supply a result with ratings and contexts.');
    end
end
function id=engine_id(r,ratings)
    if isfield(r,'engine_id'), id=string(r.engine_id); return; end
    % Compatibility with saved studies predating the explicit engine ID.
    J=jsondecode(fileread(ttpa_requirements_path()));
    file=fullfile(fileparts(ttpa_requirements_path()),J.propulsion.engine_catalog_file);
    catalog=jsondecode(fileread(file)); ids=string(fieldnames(catalog.engines));
    matches=strings(0);
    for name=reshape(ids,1,[])
        e=catalog.engines.(name);
        if J.propulsion.n_engines*e.takeoff_hp_each==ratings.P_turbine_TO && ...
                J.propulsion.n_engines*e.continuous_hp_each==ratings.P_turbine_continuous
            matches(end+1)=name; %#ok<AGROW>
        end
    end
    if numel(matches)~=1
        error('plot_concept2_constraints:EngineIdentity','Saved result needs an unambiguous engine_id.');
    end
    id=matches(1);
end
function fig=canvas(visible)
    fig=figure('Visible',visible,'Color','w','Position',[80,80,1200,820]);
end
function curves(ax,d,values,mask,colors)
    for k=reshape(find(mask),1,[])
        style='-'; if contains(d.names(k),'OEI'), style='--'; end
        plot(ax,d.WS,values(k,:),'LineStyle',style,'Color',colors(k,:), ...
            'LineWidth',1.5,'DisplayName',char(d.names(k)));
    end
end
function band(ax,x,lo,hi,mask,color,label)
    mask=mask & isfinite(hi) & hi>=lo;
    runs=diff([false,mask,false]); starts=find(runs==1); ends=find(runs==-1)-1;
    patch(ax,NaN,NaN,color,'FaceAlpha',.4,'EdgeColor','none','DisplayName',label);
    for k=1:numel(starts)
        ids=starts(k):ends(k);
        if numel(ids)<2, continue; end
        patch(ax,[x(ids),fliplr(x(ids))],[lo(ids),fliplr(hi(ids))],color, ...
            'FaceAlpha',.4,'EdgeColor','none','HandleVisibility','off');
    end
end
function finish_axes(ax,d,ymax,ylabelText,titleText)
    xline(ax,d.landing_WS_max,'--','Color',[.40,.40,.40],'LineWidth',1.5, ...
        'DisplayName','Landing wing-loading limit (water proxy)');
    xline(ax,d.span_WS_min,':','Color',[.45,.45,.45],'LineWidth',1.5, ...
        'DisplayName','Maximum-span wing-loading limit');
    xlim(ax,[0,1.05*max(d.WS)]); ylim(ax,[0,ymax]);
    xlabel(ax,'Wing loading W/S [lbf/ft^2]'); ylabel(ax,ylabelText);
    title(ax,titleText,'FontSize',14,'FontWeight','bold');
    ax.Parent.Name=titleText; ax.Parent.NumberTitle='off';
    grid(ax,'on'); ax.FontSize=11; ax.Layer='top'; box(ax,'on');
end
function note(fig,details,footer)
% Keep detailed study context available without the old table under the plot.
    fig.UserData=struct('installation_details',details,'study_notes',footer);
    ax=findobj(fig,'Type','axes');
    firstLine=splitlines(string(details));
    subtitle(ax,firstLine(1),'FontWeight','normal','FontSize',10,'Interpreter','none');
    annotation(fig,'textbox',[.085,.008,.88,.055], ...
        'String',footer(1),'Interpreter','none','FontSize',9, ...
        'EdgeColor','none','HorizontalAlignment','center');
end
function design_point(ax,x,y,label)
    plot(ax,x,y,'d','MarkerEdgeColor',[.08,.24,.55], ...
        'MarkerFaceColor',[.08,.24,.55],'MarkerSize',7, ...
        'LineWidth',1.2,'DisplayName',label);
end
function best_motor_point(ax,d,mask)
% Minimum motor rating within this sweep, with all fixed-source limits active.
    candidates=d.motor_envelope;
    candidates(~mask | ~isfinite(candidates) | candidates<=0)=NaN;
    if ~any(isfinite(candidates)), return; end
    [best,k]=max(candidates,[],'omitnan');
    plot(ax,d.WS(k),best,'kp','MarkerFaceColor','y','MarkerSize',10, ...
        'DisplayName','Minimum motor power point (fixed hybrid context)');
end
function ymax=power_axis_limit(d)
% Show all finite curves in the geometry-admissible range, like Concept 3.
    admissible=d.WS>=d.span_WS_min & d.WS<=d.landing_WS_max;
    values=d.motor_WP_limits(:,admissible);
    values=values(isfinite(values) & values>0);
    values=[values(:); d.motor_actual_WP; d.turbine_actual_WP];
    ymax=5*ceil(1.2*max(values)/5);
end
function export_plot(fig,path,visible)
    exportgraphics(fig,path,'Resolution',170);
    [folder,name]=fileparts(path); savefig(fig,fullfile(folder,[name,'.fig']));
    if ~visible, close(fig); end
end
