function fig=plot_eco_constraints(r)
%PLOT_ECO_CONSTRAINTS Show both the sizing envelope and the installed unit.
fig=figure('Name','AMP-H570 Amphibian Mission Constraints','Color','w', ...
    'Position',[80 80 1150 760]);
ax=axes(fig,'Position',[.09 .15 .88 .76]);
hold(ax,'on');
x=r.WS;
y=r.reference.WP;
green=[.74 .89 .69];
region=x<=r.WS_water_wall & r.envelope>0;
idx=find(region);
breaks=[0 find(diff(idx)>1) numel(idx)];
for k=1:numel(breaks)-1
    g=idx(breaks(k)+1:breaks(k+1));
    patch(ax,[x(g) fliplr(x(g))],[zeros(size(g)) fliplr(r.envelope(g))],green, ...
        'FaceAlpha',.65,'EdgeColor','none','HandleVisibility','off');
end
patch(ax,NaN,NaN,green,'FaceAlpha',.65,'EdgeColor','none','DisplayName', ...
    sprintf('Sizing envelope at %g KTAS',r.cruise_check.Speed_KTAS(1)));
colors=[.20 .25 .86; .00 .55 .22];
for k=1:numel(r.climb_altitudes_ft)
    plot(ax,x,r.climb_limits(k,:),'Color',colors(k,:),'LineWidth',1.7,'DisplayName', ...
        sprintf('%g° climb at %s',r.climb_angle_deg,altitude_label(r.climb_altitudes_ft(k))));
end
plot(ax,x,r.balked_limit,'Color',[.82 .49 0],'LineWidth',1.7,'DisplayName', ...
    sprintf('Balked landing (%g%%, %g s boost)',100*r.balked_gradient,r.balked_burst_s));
plot(ax,x,r.balked_fuel_limit,':','Color',[.82 .49 0],'LineWidth',1.7, ...
    'DisplayName','Balked landing (fuel only)');
cruiseStyles={'-','--'};
for k=1:height(r.cruise_check)
    style=cruiseStyles{min(k,2)};
    plot(ax,x,r.cruise_limits(k,:),style,'Color',[.02 .51 .70],'LineWidth',2, ...
        'DisplayName',sprintf('%g KTAS at %s',r.cruise_check.Speed_KTAS(k), ...
        altitude_label(r.cruise_check.Altitude_ft(k))));
end
xline(ax,r.WS_water_wall,'--','Color',[.27 .27 .27],'LineWidth',1.5, ...
    'DisplayName','50-ft water landing (proxy)');
plot(ax,x,r.total_propulsion_loss_limit,'-.','Color',[.75 .18 .20],'LineWidth',1.5, ...
    'DisplayName','Total propulsion loss (zero climb power)');
yline(ax,y,':','Color',[.38 .38 .38],'LineWidth',1.3,'DisplayName','Installed AMP-H570 W/P');
if any(r.feasible_mask)
    installed=y*ones(size(x));
    installed(~r.feasible_mask)=NaN;
    plot(ax,x,installed,'Color',[.04 .41 .19],'LineWidth',3, ...
        'DisplayName','Installed unit meets primary screen');
end
plot(ax,r.reference.WS,y,'p','MarkerSize',16,'MarkerFaceColor',[1 .80 .1], ...
    'MarkerEdgeColor','k','DisplayName',sprintf('Loaded reference (%.2f, %.2f)',r.reference.WS,y));
xlim(ax,r.WS_range);
ylim(ax,[-.6 1.1*max([30,y,r.balked_limit,r.balked_fuel_limit,r.climb_limits(:)',r.cruise_limits(:)'])]);
grid(ax,'on'); ax.Box='on'; ax.Toolbar.Visible='off';
xlabel(ax,'Wing loading W_{TO}/S (lbf/ft^2)');
ylabel(ax,'Power loading W_{TO}/P_{SL,peak} (lbf/shp)');
title(ax,'Grand Caravan EX Amphibian with AMP-H570');
legend(ax,'Location','northeast','FontSize',8);
annotation(fig,'textbox',[.09 .025 .88 .08],'String', ...
    {'Green area uses scaled peak and continuous ratings. The horizontal line is the fixed installed unit at the loaded weight.', ...
    'Shading uses the mission cruise speed and excludes propulsion failure. Water landing and boost remain screening assumptions.'}, ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',8.5);
end

function label=altitude_label(altitude)
if altitude==0, label='sea level'; else, label=sprintf('%g ft',altitude); end
end
