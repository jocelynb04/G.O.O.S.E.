function figures=plot_concept4_constraints(r,output,visible)
%PLOT_CONCEPT4_CONSTRAINTS Caravan-style axes, colors, reference star and box.
if nargin<3,visible=false;end
if ~isfolder(output),mkdir(output);end
vis='off';if visible,vis='on';end
waterText='Water landing proxy is not met at this W/S';
if r.reference.WS<=r.water_wall_psf,waterText='Water landing proxy is met at this W/S';end
x=r.WS;R=r.reference;colors=[.20 .25 1;.05 .65 .25;.9 .1 .1;.82 .53 0;.08 .60 .85];
fig=figure('Name','Concept 4 Seaplane Mission Constraint Diagram','Color','w','Visible',vis,'Position',[80 80 1150 760]);
ax=axes(fig,'Position',[.085 .17 .89 .75]);hold(ax,'on');
mask=r.span_ft<65 & isfinite(r.flight_envelope);
patch(ax,[x(mask),fliplr(x(mask))],[zeros(1,sum(mask)),fliplr(r.flight_envelope(mask))],[.78 .93 .66], ...
 'FaceAlpha',.7,'EdgeColor','none','DisplayName','Flight-power sizing region (span screened)');
labels={'2,000-fpm climb at sea level','500-fpm climb at 10,000 ft', ...
 '450-fpm one-motor-out ideal screen','Electric balked landing (3% gradient)','180-KTAS cruise at 10,000 ft'};
for k=1:5
 style='-';if k==3,style='--';end
 plot(ax,x,r.motor_limits(k,:),style,'Color',colors(k,:),'LineWidth',1.8,'DisplayName',labels{k});
end
xline(ax,r.water_wall_psf,'--','Color',[.25 .25 .25],'LineWidth',1.7,'DisplayName',sprintf('50-ft water landing proxy (assumed %.2f g)',r.water_proxy.effective_deceleration_g));
xline(ax,r.span_wall_psf,':','Color',[.5 .5 .5],'LineWidth',1.5,'DisplayName','65-ft strict span boundary');
plot(ax,R.WS,R.WP,'p','MarkerSize',16,'MarkerFaceColor',[1 .85 .1],'MarkerEdgeColor','k','LineWidth',1.1, ...
 'DisplayName','OpenVSP geometry at evaluation weight');
limit=interp1(x,r.flight_envelope,R.WS);
plot(ax,[R.WS R.WS],[R.WP limit],':k','HandleVisibility','off');
text(ax,12,22,sprintf(['OpenVSP Concept 4 reference\nW = %.0f lb; S = %.0f ft^2; b = %.2f ft\n' ...
 'W/S = %.2f; W/P_{motor} = %.2f\nMotor = %.0f hp nameplate\nGenerator = %.0f hp total\n%s'], ...
 R.W_lb,R.S_ft2,R.span_ft,R.WS,R.WP,R.motor_hp,R.generator_total_hp,waterText), ...
 'FontSize',9,'Color','k','VerticalAlignment','bottom','BackgroundColor','w','EdgeColor',[.6 .6 .65],'Margin',7);
styleAxes(ax,'Concept 4 Seaplane Mission Constraint Diagram','Motor power loading W_{TO}/P_{motor,rated} (lbf/hp)',r.plot_settings);
legend(ax,'Location','northeast','FontSize',8,'Box','on','Color','w','TextColor','k','EdgeColor',[.6 .6 .65]);
annotation(fig,'textbox',[.085 .02 .89 .09],'String',{ ...
 'Green is a flight-power sizing screen. The wing alone changes across W/S; the CAD body, tail, floats and pods stay fixed.', ...
 'Water distances, pack/mission energy, mass closure and failed-source control/endurance are separate checks. Motor-out curve excludes failed-prop drag/yaw.', ...
 sprintf('Reference uses %.0f lb and the synchronized %.0f-ft^2, %.0f-ft-span OpenVSP model. Water deceleration is an explicit assumption.',R.W_lb,R.S_ft2,R.span_ft)}, ...
 'EdgeColor','none','FontSize',8.5,'Color',[.25 .25 .25],'HorizontalAlignment','center');
exportFigure(fig,fullfile(output,'concept4_matching_diagram'));
figures.motor=fig;

fg=figure('Name','Concept 4 Generator Constraint Diagram','Color','w','Visible',vis,'Position',[80 80 1150 760]);
ag=axes(fg,'Position',[.085 .17 .89 .75]);hold(ag,'on');
patch(ag,[x(mask),fliplr(x(mask))],[zeros(1,sum(mask)),fliplr(r.generator_envelope(mask))],[.78 .93 .66], ...
 'FaceAlpha',.7,'EdgeColor','none','DisplayName','Generator sizing screen (scheduled battery assist)');
for k=1:3
 lab={'2,000-fpm climb generator share','500-fpm climb generator share','180-KTAS sustained cruise supply'};
 c=colors(k,:);if k==3,c=colors(5,:);end
 plot(ag,x,r.generator_limits(k,:),'Color',c,'LineWidth',1.8,'DisplayName',lab{k});
end
xline(ag,r.span_wall_psf,':','Color',[.5 .5 .5],'LineWidth',1.5,'DisplayName','65-ft strict span boundary');
plot(ag,R.WS,R.generator_WP,'p','MarkerSize',16,'MarkerFaceColor',[1 .85 .1],'MarkerEdgeColor','k','LineWidth',1.1,'DisplayName','Installed generator study rating');
text(ag,12,22,sprintf('OpenVSP Concept 4 reference\nW = %.0f lb; S = %.0f ft^2\nGenerator = %.0f hp total\nW/P_{generator} = %.2f\nClimb battery contribution follows mission phi',R.W_lb,R.S_ft2,R.generator_total_hp,R.generator_WP), ...
 'FontSize',9,'Color','k','VerticalAlignment','bottom','BackgroundColor','w','EdgeColor',[.6 .6 .65],'Margin',7);
styleAxes(ag,'Concept 4 Generator Power Constraint Diagram','Generator power loading W_{TO}/P_{generator,rated} (lbf/hp)',r.plot_settings);
legend(ag,'Location','northeast','FontSize',8,'Box','on','Color','w','TextColor','k','EdgeColor',[.6 .6 .65]);
annotation(fg,'textbox',[.085 .025 .89 .08],'String',{ ...
 'Generator power is engine shaft power before electrical conversion. It is not added to motor shaft rating.', ...
 'Climb uses the declared battery share; battery duration and recharge require a mission check. The single-generator-loss endurance remains unresolved.'}, ...
 'EdgeColor','none','FontSize',8.5,'Color',[.25 .25 .25],'HorizontalAlignment','center');
exportFigure(fg,fullfile(output,'concept4_generator_constraints'));
figures.generator=fg;
end
function styleAxes(ax,titleText,ylabelText,settings)
xlim(ax,settings.wing_loading_range_psf);ylim(ax,settings.power_loading_limits);grid(ax,'on');ax.GridAlpha=.14;ax.GridColor=[0 0 0];ax.Color='w';ax.XColor='k';ax.YColor='k';ax.Title.Color='k';ax.Box='on';ax.FontSize=10;ax.Toolbar.Visible='off';
xlabel(ax,'Wing loading W_{TO}/S (lbf/ft^2)');ylabel(ax,ylabelText);title(ax,titleText,'FontWeight','bold','FontSize',12);
end
function exportFigure(fig,path)
exportgraphics(fig,[path '.png'],'Resolution',180,'BackgroundColor','white','Padding',12);exportgraphics(fig,[path '.pdf'],'ContentType','vector','BackgroundColor','white','Padding',12);savefig(fig,[path '.fig']);
end
