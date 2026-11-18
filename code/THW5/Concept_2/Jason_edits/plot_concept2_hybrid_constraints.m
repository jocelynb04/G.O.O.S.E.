function [fig,r]=plot_concept2_hybrid_constraints(d,peak_shp,visible)
%PLOT_CONCEPT2_HYBRID_CONSTRAINTS Caravan-style common peak-power reference.
% Each source-specific limit is W/P_ref * available/required, matching the
% Hybrid_MultiEngine diagram's normalization. Source dispatch, battery/SOC,
% failures and durations remain those of the assessed Concept 2 installation.
% The filled area is a fixed-ratio scaling reference, not a catalog engine
% resizing prediction. The green horizontal segment tests actual hardware.
    validateattributes(peak_shp,{'numeric'},{'scalar','positive','finite'});
    referenceWP=d.W_TO/peak_shp;
    limits=referenceWP*d.power_margin_ratio(d.power_cases,:);
    envelope=min(limits,[],1,'includenan');
    valid=d.geometry_ok & ~d.unknown & ...
        ~d.metadata.capacity_is_failed_search_bound;
    feasible=valid & d.current_installation_pass;
    [~,j]=min(abs(d.WS-d.trial_WS));
    names=d.names(d.power_cases);
    sources=d.sources(d.power_cases);
    required=d.required_hp(d.power_cases,j);
    available=d.available_hp(d.power_cases,j);
    status=d.status(d.power_cases,j);
    r=struct('WS',d.WS,'WS_range',[min(d.WS),max(d.WS)], ...
        'limits',limits,'envelope',envelope,'feasible_mask',feasible, ...
        'water_wall',d.landing_WS_max,'span_wall',d.span_WS_min);
    r.reference=struct('WS',d.trial_WS,'WP',referenceWP,'weight_lb',d.W_TO, ...
        'peak_shp',peak_shp,'passes_primary_screen',feasible(j));
    r.reference_power=table(names,sources,required,available,available-required, ...
        status=="pass",'VariableNames', ...
        {'Condition','Source','Required_shp','Available_shp','Margin_shp','PowerPass'});
    r.metadata=struct('power_basis',"Net sea-level combined peak shaft power", ...
        'normalization',"W/P_ref times source-specific available/required power", ...
        'envelope_interpretation',"Fixed-ratio scaling reference only", ...
        'mission_recomputed_across_sweep',false, ...
        'weight_closed',d.metadata.weight_closed, ...
        'SOC_policy',d.metadata.SOC_policy);
    onoff='off'; if visible, onoff='on'; end
    fig=figure('Name','Concept 2 Twin Hybrid Constraints','Color','w', ...
        'Position',[100,100,1200,820],'Visible',onoff,'NumberTitle','off');
    ax=axes('Parent',fig,'Position',[.085,.14,.89,.76]); hold(ax,'on');
    green=[.77,.91,.71];
    shade(ax,d.WS,envelope,valid,green);
    colors=[.15,.35,.78; .72,.16,.20; .78,.46,0; .05,.57,.65; ...
        .49,.27,.69; .30,.55,.18; .45,.45,.45];
    for k=1:numel(names)
        style='-'; if contains(names(k),'OEI'), style='--'; end
        plot(ax,d.WS,limits(k,:),style,'Color',colors(mod(k-1,7)+1,:), ...
            'LineWidth',1.7,'DisplayName',names(k));
    end
    plot(ax,d.WS,envelope,'k-','LineWidth',2.1,'DisplayName','All-constraint envelope');
    xline(ax,d.landing_WS_max,'--','Color',[.30,.30,.30], ...
        'DisplayName','Water landing proxy');
    xline(ax,d.span_WS_min,':','Color',[.45,.45,.45], ...
        'DisplayName','Maximum-span limit');
    yline(ax,referenceWP,':','Color',[.40,.40,.40], ...
        'DisplayName','Installed pair at trial weight');
    installed=referenceWP*ones(size(d.WS)); installed(~feasible)=NaN;
    if any(feasible)
        plot(ax,d.WS,installed,'Color',[.08,.42,.18],'LineWidth',3, ...
            'DisplayName','Installed pair meets all static checks');
    end
    plot(ax,d.trial_WS,referenceWP,'p','MarkerSize',15, ...
        'MarkerFaceColor',[1,.82,.12],'MarkerEdgeColor','k', ...
        'DisplayName','Concept 2 twin reference');
    xlim(ax,r.WS_range);
    values=[referenceWP;limits(:)]; values=values(isfinite(values));
    ylim(ax,[0,1.06*max(values)]);
    grid(ax,'on'); box(ax,'on'); ax.FontSize=11;
    xlabel(ax,'Wing loading W_{TO}/S (lbf/ft^2)');
    ylabel(ax,'Power loading W_{TO}/P_{SL,peak} (lbf/shp)');
    title(ax,'Concept 2 Twin Hybrid Amphibian');
    subtitle(ax,sprintf('W = %.0f lb | Combined peak reference = %.0f shp | Fixed mission SOC and source ratios', ...
        d.W_TO,peak_shp),'FontSize',10,'FontWeight','normal');
    legend(ax,'Location','northeast','FontSize',8,'NumColumns',2,'Interpreter','none');
    state="Weight not closed"; if d.metadata.weight_closed, state="Weight closure converged"; end
    if isfield(d,'intact_buoyancy_met') && ~d.intact_buoyancy_met
        state=state+sprintf(' | Float volume FAIL: %.1f / %.1f ft3 required', ...
            d.float_volume_available_ft3,d.float_volume_required_ft3);
    end
    if d.metadata.capacity_is_failed_search_bound
        state=state+" | Battery capacity search FAILED; pack value is a search bound";
    end
    annotation(fig,'textbox',[.085,.008,.89,.06], ...
        'String',state+" | Green area: fixed-ratio reference; green line: installed hardware checks. Mission not re-simulated across sweep.", ...
        'EdgeColor','none','HorizontalAlignment','center','FontSize',9,'Interpreter','none');
    fig.UserData=r;
end

function shade(ax,x,envelope,valid,color)
    mask=valid & isfinite(envelope) & envelope>0;
    transitions=diff([false,mask,false]);
    starts=find(transitions==1); ends=find(transitions==-1)-1;
    patch(ax,NaN,NaN,color,'EdgeColor','none', ...
        'DisplayName','Fixed-ratio hybrid reference envelope');
    for k=1:numel(starts)
        ids=starts(k):ends(k);
        if numel(ids)<2, continue; end
        patch(ax,[x(ids),fliplr(x(ids))], ...
            [zeros(size(ids)),fliplr(envelope(ids))],color, ...
            'EdgeColor','none','HandleVisibility','off');
    end
end
