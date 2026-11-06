function fig=plot_caravan_constraints(r)
% Conventional Caravan-only mission constraint chart.
c=r.settings; speed=164;
if isfield(c,'plot_required_cruise_ktas'), speed=c.plot_required_cruise_ktas; end
idx=find([r.cases.speed_ktas]==speed,1);
assert(~isempty(idx),'Constraints:PlotSpeed','Requested plotting speed must be included in cruise_speeds_ktas.');
s=r.cases(idx); x=r.WS;
fig=figure('Name','Caravan EX Amphibian Mission Constraint Diagram', ...
    'Color','w','Position',[80 80 1150 760]);
ax=axes(fig,'Position',[.085 .15 .89 .77]); hold(ax,'on');
ytop=c.plot_power_loading_limits(2);
% Full numerical region, with engine resizing allowed. OEI positive climb is excluded.
valid=x<=r.WS_water_wall & s.envelope>0;
if c.require_powered_oei, valid(:)=false; end
shade(valid,zeros(size(x)),s.envelope,[.78 .93 .66],.7);
h(1)=patch(ax,NaN,NaN,[.78 .93 .66],'EdgeColor','none');
h(2)=plot(ax,x,r.climb_limits(1,:),'Color',[.20 .25 1],'LineWidth',1.8);
h(3)=plot(ax,x,r.climb_limits(2,:),'Color',[.05 .65 .25],'LineWidth',1.8);
h(4)=plot(ax,x,r.oei_positive_climb_limit,'Color',[.9 .1 .1],'LineWidth',2);
h(5)=plot(ax,x,r.balked_limit,'Color',[.82 .53 0],'LineWidth',1.8);
h(6)=plot(ax,x,s.cruise_limit,'Color',[.08 .60 .85],'LineWidth',2.2);
h(7)=xline(ax,r.WS_water_wall,'--','Color',[.25 .25 .25],'LineWidth',1.7);
showcap=isfield(c,'show_installed_power_boundary') && c.show_installed_power_boundary;
if showcap
    yline(ax,r.power_loading_floor,':','Color',[.40 .40 .40],'LineWidth',1.3,'HandleVisibility','off');
end
% Select the existing aircraft: no silent wing/engine redesign for a style change.
px=r.reference.WS; py=r.reference.WP;
h(8)=plot(ax,px,py,'p','MarkerSize',16,'MarkerFaceColor',[1 .85 .1], ...
    'MarkerEdgeColor','k','LineWidth',1.1);
limits=[interp1(x,r.climb_limits(1,:),px),interp1(x,r.climb_limits(2,:),px), ...
    interp1(x,r.balked_limit,px),interp1(x,s.cruise_limit,px)];
labels={'Sea-level climb','10,000-ft climb','Balked landing',sprintf('%.0f-KTAS cruise',speed)};
[~,driver]=min(limits);
p=grand_caravan_ex_params();
boxX=36; boxY=23;
limit=interp1(x,s.envelope,px);
plot(ax,[px px],[py limit],':','Color','k','LineWidth',1.3,'HandleVisibility','off');
plot(ax,px,limit,'kx','MarkerSize',7,'LineWidth',1.3,'HandleVisibility','off');
text(ax,boxX,boxY,sprintf(['Caravan EX Amphibian reference\nW/S = %.2f lbf/ft^2\nW/P = %.2f lbf/shp\n' ...
    'S = %.0f ft^2; P = %.0f shp\nb = %.2f ft\nTightest power curve: %s'], ...
    px,py,p.S_ref_ft2,p.P_SL_shp,p.span_ft,labels{driver}), ...
    'FontSize',9,'VerticalAlignment','bottom','BackgroundColor','w', ...
    'EdgeColor',[.6 .6 .65],'Margin',7,'Interpreter','tex');
xlim(ax,c.wing_loading_range_psf); ylim(ax,[0 ytop]);
ap=ax.Position; xr=c.wing_loading_range_psf;
arrowX=ap(1)+([boxX px]-xr(1))/diff(xr)*ap(3);
arrowY=ap(2)+[boxY-1 py+.3]/ytop*ap(4);
annotation(fig,'arrow',arrowX,arrowY,'Color',[.25 .25 .25],'LineWidth',1.1,'HeadLength',6,'HeadWidth',6);
grid(ax,'on'); ax.GridAlpha=.14; ax.Box='on'; ax.FontSize=10; ax.Toolbar.Visible='off';
xlabel(ax,'Wing loading W_{TO}/S (lbf/ft^2)');
ylabel(ax,'Power loading W_{TO}/P_{SL} (lbf/shp)');
title(ax,'Grand Caravan EX Amphibian Mission Constraint Diagram','FontWeight','bold','FontSize',12);
if string(c.climb_requirement_type)=="angle", climbtext=sprintf('%.0f-deg climb',c.climb_angle_deg);
else, climbtext='Required ROC'; end
legend(ax,h,{sprintf('Numerical AEO feasible region - %.0f KTAS',speed), ...
    [climbtext ' at sea level'],[climbtext ' at 10,000 ft'],'OEI: no positive powered climb', ...
    'Balked landing (3% gradient)',sprintf('Caravan %.0f-KTAS cruise constraint',speed), ...
    'Water landing over 50 ft (calibrated proxy)', ...
    sprintf('Caravan reference (%.2f, %.2f)',px,py)}, ...
    'Location','northeast','FontSize',8,'Box','on');
annotation(fig,'textbox',[.085 .025 .89 .075],'String', ...
    {'Conventional PT6-powered Caravan EX Amphibian only. Reference point: 9062 lb, 279 ft^2, 867 shp.', ...
    'Shading permits engine resizing; water wall and performance model are provisional. Positive OEI powered climb is excluded from AEO shading.'}, ...
    'EdgeColor','none','FontSize',8.5,'Color',[.25 .25 .25],'HorizontalAlignment','center');
    function shade(mask,lower,upper,color,alpha)
        indices=find(mask); if isempty(indices), return; end
        first=[1 find(diff(indices)>1)+1]; last=[first(2:end)-1 numel(indices)];
        for j=1:numel(first)
            g=indices(first(j):last(j));
            if numel(g)>1
                patch(ax,[x(g) fliplr(x(g))],[lower(g) fliplr(upper(g))],color, ...
                    'FaceAlpha',alpha,'EdgeColor','none','HandleVisibility','off');
            end
        end
    end
end
