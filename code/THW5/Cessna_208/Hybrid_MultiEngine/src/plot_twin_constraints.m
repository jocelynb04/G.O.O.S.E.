function fig=plot_twin_constraints(r)
% Show the numerical sizing envelope and the installed twin reference.
fig=figure('Name','Twin Hybrid Amphibian Constraints','Color','w', ...
    'Position',[100 100 1100 700]);
ax=axes('Parent',fig);
hold(ax,'on');
x=r.WS;
y=r.reference.WP;
inside=x<=r.water_wall;
green=[.77 .91 .71];
patch(ax,[x(inside) fliplr(x(inside))], ...
    [zeros(1,nnz(inside)) fliplr(r.envelope(inside))],green, ...
    'EdgeColor','none','DisplayName',sprintf('Sizing envelope with %g-KTAS cruise and OEI',r.primary_cruise_ktas));
colors=[.15 .35 .78;.15 .35 .78;.72 .16 .20;.72 .16 .20;.78 .46 0;.05 .57 .65];
for k=1:height(r.reference_power)
    color=colors(min(k,6),:);
    style='-';
    if ismember(k,[2 4]) || k>6, style='--'; end
    plot(ax,x,r.limits(k,:),style,'Color',color,'LineWidth',1.7, ...
        'DisplayName',r.reference_power.Condition(k));
end
xline(ax,r.water_wall,'--','Color',[.30 .30 .30], ...
    'DisplayName','50-ft water landing proxy');
yline(ax,y,':','Color',[.40 .40 .40],'DisplayName','Installed pair at loaded weight');
if any(r.feasible_mask)
    installed=y*ones(size(x));
    installed(~r.feasible_mask)=NaN;
    plot(ax,x,installed,'Color',[.08 .42 .18],'LineWidth',3, ...
        'DisplayName','Installed pair meets primary screen');
end
plot(ax,r.reference.WS,y,'p','MarkerSize',15,'MarkerFaceColor',[1 .82 .12], ...
    'MarkerEdgeColor','k','DisplayName','Loaded twin reference');
xlim(ax,r.WS_range);
ylim(ax,[0 1.06*max([y;r.limits(:)])]);
grid(ax,'on');
box(ax,'on');
xlabel(ax,'Wing loading W_{TO}/S (lbf/ft^2)');
ylabel(ax,'Power loading W_{TO}/P_{SL,peak} (lbf/shp)');
title(ax,'Twin Hybrid Grand Caravan EX Amphibian');
legend(ax,'Location','northeast','FontSize',8);
end
