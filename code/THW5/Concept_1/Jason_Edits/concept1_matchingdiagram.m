function analysis = concept1_matchingdiagram(writeResults)
%CONCEPT1_MATCHINGDIAGRAM Concept 1 curves, envelope, reference and design point.
% Plot-only entry, with a Concept 3 style returned analysis struct.
% Wing area varies at fixed AR. Other imported components stay fixed.
% W/P uses turbine rating. Electric rating scales at the selected source ratio.
if nargin == 0, writeResults = true; end
setup_jason_edits();
here = fileparts(mfilename('fullpath'));
J = jsondecode(fileread(concept1_requirements_path()));
obj = concept1_disciplines();
W0 = J.analysis_design.takeoff_weight_lbf;
S = obj.geom.S_ref; AR = obj.geom.AR;
WS = W0/S; WP = W0/obj.prop.P_SL;
[~,landingWall,~,~,~,detail] = concept1_matching_envelope(WS,obj);
spanWall = W0*AR/J.aircraft_requirements.maximum_wingspan_ft^2;
curveIds = find(detail.is_curve);
out = fullfile(here,'results');
if writeResults && ~isfolder(out), mkdir(out); end
% The sweep changes only wing area at fixed AR, retaining the imported
% tails, body, nacelles and floats. At WS the shape matches the input model.
settings = J.constraints;
range = settings.wing_loading_range_psf;
sweep = unique([linspace(range(1),range(2),settings.wing_loading_points),spanWall,landingWall,WS]);
curves = zeros(numel(curveIds),numel(sweep));
env = zeros(size(sweep));
for k = 1:numel(sweep)
    obj.geom.S_ref = W0/sweep(k);
    [env(k),~,~,~,~,d] = concept1_matching_envelope(sweep(k),obj);
    curves(:,k) = d.WP_all(curveIds);
end
obj.geom.S_ref = S;
fig = figure('Name','OpenVSP Concept 1 constraints','Color','w','Position',[90 90 1350 800]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for k = 1:numel(curveIds)
    plot(ax,sweep,curves(k,:),'LineWidth',1.4,'DisplayName',detail.names(curveIds(k)));
end
plot(ax,sweep,env,'k','LineWidth',2.4,'DisplayName','Constraint envelope');
xline(ax,spanWall,':','LineWidth',2,'DisplayName','Minimum W/S from 65 ft span');
xline(ax,landingWall,'--','Color',[.65 .18 .13],'LineWidth',2,'DisplayName','Maximum W/S from water landing');
plot(ax,WS,WP,'o','MarkerSize',11,'MarkerFaceColor',[.8 .19 .16], ...
    'MarkerEdgeColor','k','DisplayName','Imported geometry at selected weight');
reference = settings.design_point;
plot(ax,reference.wing_loading_psf,reference.power_loading_lb_per_hp,'d','MarkerSize',9,'MarkerFaceColor',[.95 .7 .18], ...
    'MarkerEdgeColor','k','DisplayName','Grand Caravan EX Amphibian reference');
if spanWall<landingWall
    mask = sweep>=spanWall & sweep<=landingWall;
    patch(ax,[sweep(mask),fliplr(sweep(mask))],[env(mask),zeros(size(env(mask)))], ...
        [.4 .7 .6],'FaceAlpha',.2,'EdgeColor','none','DisplayName','Modeled feasible region');
else
    text(ax,12,2.0,'No feasible wing-loading band at this weight and aspect ratio', ...
        'FontSize',12,'Color',[.65 .1 .1]);
end
xlabel(ax,'Wing loading (lbf/ft^2)');
ylabel(ax,'Weight / rated turbine power (lbf/hp)');
title(ax,'Concept 1 constraints from the imported OpenVSP geometry');
subtitle(ax,sprintf('%.0f lbf | %.0f ft^2 wing | %.2f ft projected span | fixed power-source rating ratio',W0,S,obj.geom.b));
xlim(ax,[0 max([range(2),WS,reference.wing_loading_psf])*1.05]); ylim(ax,[0 inf]);
legend(ax,'Location','southoutside','NumColumns',2,'Box','off','FontSize',9);
valid = sweep >= spanWall & sweep <= landingWall & env > 0 & isfinite(env);
WS_best = NaN; WP_best = NaN;
if any(valid)
    ids = find(valid);
    [WP_best,j] = max(env(valid));
    WS_best = sweep(ids(j));
    plot(ax,WS_best,WP_best,'kp','MarkerFaceColor','y','MarkerSize',10, ...
        'DisplayName','Minimum turbine rating at fixed electric/turbine ratio');
end
analysis = struct('WS_sweep',sweep,'WP_limits',curves, ...
    'condition_names',detail.names(curveIds),'WP_envelope',env, ...
    'WS_wall',landingWall,'WS_span_min',spanWall,'WS_best',WS_best,'WP_best',WP_best, ...
    'design_point',reference,'concept1_design_point', ...
    struct('wing_loading_psf',WS,'power_loading_lb_per_hp',WP), ...
    'feasible',valid,'figure',fig);
if writeResults
    % Export after adding the minimum-power marker.
    exportgraphics(fig,fullfile(out,'OpenVSP_matching_diagram.png'),'Resolution',150);
    savefig(fig,fullfile(out,'OpenVSP_matching_diagram.fig'));
    curvesTable = array2table([sweep(:),curves',env(:),valid(:)], ...
        'VariableNames',["WingLoading_lbf_ft2",matlab.lang.makeValidName(detail.names(curveIds)), ...
        "Envelope_lbf_hp","WithinSpanAndLandingBand"]);
    writetable(curvesTable,fullfile(out,'OpenVSP_constraint_curves.csv'));
    data = rmfield(analysis,'figure');
    save(fullfile(out,'OpenVSP_matching_analysis.mat'),'data');
end
end
