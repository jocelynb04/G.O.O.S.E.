function fig=plot_twin_hybrid(r)
%PLOT_TWIN_HYBRID Plot battery charge per side and total fuel remaining.
fig=figure('Name','Twin Hybrid Caravan Amphibian','Color','w');
ax=axes('Parent',fig);
yyaxis(ax,'left');
plot(ax,r.trace.time_min,100*r.trace.soc,'LineWidth',1.5);
ylabel(ax,'SOC per side (%)');
yyaxis(ax,'right');
plot(ax,r.trace.time_min,r.trace.fuel_remaining_lb,'LineWidth',1.5);
ylabel(ax,'Fuel remaining (lb)');
xlabel(ax,'Elapsed time (min)');
grid(ax,'on');
title(ax,'Mission energy and fuel');
end
