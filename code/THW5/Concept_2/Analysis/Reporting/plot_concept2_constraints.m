function [files,data]=plot_concept2_constraints(result,varargin)
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
        'data_mat',fullfile(out,'constraint_diagram_data.mat'), ...
        'data_csv',fullfile(out,'constraint_diagram_data.csv'));
    colors=lines(numel(data.names));
    visible='off'; if A.visible, visible='on'; end
    ymax=max(45,2*max(data.motor_actual_WP,data.turbine_actual_WP));
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
    fig=canvas(visible); ax=axes(fig,'Position',[.075,.20,.64,.68]); hold(ax,'on');
    mask=data.geometry_ok & data.motor_hard_limits_ok & ~data.unknown & ~bound;
    band(ax,data.WS,zeros(size(WS)),min(ymax,data.motor_envelope),mask,[.66,.83,.35], ...
        'Conditional static power region');
    curves(ax,data,data.motor_WP_limits,data.motor_cases,colors);
    plot(ax,data.WS,data.motor_envelope,'k-','LineWidth',2.3,'DisplayName','Motor-rating envelope');
    yline(ax,data.motor_actual_WP,'--','Color',[.42,.30,.16],'LineWidth',1.5, ...
        'DisplayName','Installed motor peak loading');
    plot(ax,trialWS,data.motor_actual_WP,'p','MarkerSize',15,'MarkerFaceColor',[1,.80,.10], ...
        'MarkerEdgeColor','k','LineWidth',1.2,'DisplayName','Trial motor installation');
    finish_axes(ax,data,ymax,'Motor peak power loading W_{TO}/P_{motor,peak} [lb/hp]', ...
        'Concept 2: electric and combined-source motor constraints');
    legend(ax,'Location','eastoutside','FontSize',9,'Interpreter','none');
    note(fig,annotationText,[footer, ...
        "Motor sizing holds peak/continuous ratio fixed. Zero boundary = hard source limit or stalled condition."]);
    export_plot(fig,files.motor_png,A.visible);

    % 2. Required turbine equivalents reference the selected engine map.
    % The ONLY hardware prediction is the actual catalog-loading line. Shade
    % a thin band on that line, rather than suggesting arbitrary GE resizing.
    fig=canvas(visible); ax=axes(fig,'Position',[.075,.20,.64,.68]); hold(ax,'on');
    mask=data.current_installation_pass & ~bound;
    band(ax,data.WS,repmat(.96*data.turbine_actual_WP,size(WS)), ...
        repmat(1.04*data.turbine_actual_WP,size(WS)),mask,[.66,.83,.35], ...
        'Selected installation passes static checks');
    curves(ax,data,data.turbine_WP_reference_limits,data.turbine_cases,colors);
    plot(ax,data.WS,data.turbine_reference_envelope,'k-','LineWidth',2.3, ...
        'DisplayName','Required-rating reference envelope');
    yline(ax,data.turbine_actual_WP,'--','Color',[.42,.30,.16],'LineWidth',1.5, ...
        'DisplayName','Fixed catalog turbine loading');
    plot(ax,trialWS,data.turbine_actual_WP,'p','MarkerSize',15,'MarkerFaceColor',[1,.80,.10], ...
        'MarkerEdgeColor','k','LineWidth',1.2,'DisplayName','Selected turbine installation');
    finish_axes(ax,data,ymax,'Turbine TO-reference power loading W_{TO}/P_{turbine,TO} [lb/hp]', ...
        'Concept 2: turbine requirement references (catalog hardware fixed)');
    legend(ax,'Location','eastoutside','FontSize',9,'Interpreter','none');
    note(fig,annotationText,[footer, ...
        "Curves use the selected turbine map as a reference; GE engines are not resized."]);
    export_plot(fig,files.turbine_png,A.visible);

    % 3. An actual-installation ratio avoids mixing electric and turbine hp
    % into a fictitious universal P_SL. Every active curve must be >= 1.
    fig=canvas(visible); ax=axes(fig,'Position',[.075,.20,.64,.68]); hold(ax,'on');
    finite=data.power_margin_ratio(isfinite(data.power_margin_ratio));
    marginMax=4;
    if ~isempty(finite), marginMax=max(2,min(8,1.1*max(finite))); end
    band(ax,data.WS,ones(size(WS)),min(marginMax,data.margin_envelope), ...
        data.current_installation_pass & ~bound,[.66,.83,.35],'All static source checks pass');
    curves(ax,data,data.power_margin_ratio,data.power_cases,colors);
    plot(ax,data.WS,data.margin_envelope,'k-','LineWidth',2.5,'DisplayName','Minimum margin: all power cases');
    yline(ax,1,'--','Color',[.60,.16,.16],'LineWidth',1.6,'DisplayName','Required threshold = 1');
    plot(ax,trialWS,data.margin_envelope(trial),'p','MarkerSize',15, ...
        'MarkerFaceColor',[1,.80,.10],'MarkerEdgeColor','k','LineWidth',1.2, ...
        'DisplayName','Trial bottleneck margin');
    finish_axes(ax,data,marginMax,'Available shaft power / required shaft power [-]', ...
        'Concept 2: fixed-installation source power margins');
    legend(ax,'Location','eastoutside','FontSize',9,'Interpreter','none');
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
    fig=figure('Visible',visible,'Color','w','Position',[60,60,1440,920]);
end
function curves(ax,d,values,mask,colors)
    for k=reshape(find(mask),1,[])
        style='-'; if contains(d.names(k),'OEI'), style='--'; end
        plot(ax,d.WS,values(k,:),'LineStyle',style,'Color',colors(k,:), ...
            'LineWidth',1.7,'DisplayName',char(d.names(k)));
    end
end
function band(ax,x,lo,hi,mask,color,label)
    mask=mask & isfinite(hi) & hi>=lo;
    runs=diff([false,mask,false]); starts=find(runs==1); ends=find(runs==-1)-1;
    patch(ax,NaN,NaN,color,'FaceAlpha',.34,'EdgeColor','none','DisplayName',label);
    for k=1:numel(starts)
        ids=starts(k):ends(k);
        if numel(ids)<2, continue; end
        patch(ax,[x(ids),fliplr(x(ids))],[lo(ids),fliplr(hi(ids))],color, ...
            'FaceAlpha',.34,'EdgeColor','none','HandleVisibility','off');
    end
end
function finish_axes(ax,d,ymax,ylabelText,titleText)
    xline(ax,d.landing_WS_max,'--','Color',[.40,.40,.40],'LineWidth',1.5, ...
        'DisplayName','Water landing W/S wall (proxy)');
    xline(ax,d.span_WS_min,':','Color',[.45,.45,.45],'LineWidth',1.5, ...
        'DisplayName','Maximum-span W/S wall');
    xlim(ax,[min(d.WS),max(d.WS)]); ylim(ax,[0,ymax]);
    xlabel(ax,'Wing loading W_{TO}/S [lb/ft^2]'); ylabel(ax,ylabelText);
    title(ax,titleText,'FontSize',14,'FontWeight','bold');
    grid(ax,'on'); ax.FontSize=11; ax.Layer='top'; box(ax,'on');
end
function note(fig,text,footer)
    annotation(fig,'textbox',[.075,.078,.64,.065],'String',text, ...
        'Interpreter','none','FontSize',9,'EdgeColor',[.7,.7,.7],'BackgroundColor','w');
    annotation(fig,'textbox',[.075,.002,.90,.067],'String',footer, ...
        'Interpreter','none','FontSize',8,'EdgeColor','none','HorizontalAlignment','left');
end
function export_plot(fig,path,visible)
    exportgraphics(fig,path,'Resolution',170);
    [folder,name]=fileparts(path); savefig(fig,fullfile(folder,[name,'.fig']));
    if ~visible, close(fig); end
end
