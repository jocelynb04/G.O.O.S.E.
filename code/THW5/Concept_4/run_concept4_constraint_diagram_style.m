function out = run_concept4_constraint_diagram_style()
root = fileparts(mfilename('fullpath'));
requirements_file = fullfile(root,'concept4_aero_hydro_requirements.json');
if ~isfile(requirements_file)
    requirements_file = fullfile(root,'concept4_aero_hydro_requirements(2).json');
end
assumptions_file = fullfile(root,'concept4_integration_assumptions.json');
if ~isfile(assumptions_file)
    assumptions_file = fullfile(root,'Concept4_integration_assumptions.json');
end
J = jsondecode(fileread(requirements_file));
A = jsondecode(fileread(assumptions_file));

W = 12500;
prop = SeaplaneProp_Concept4(J);
geom = SeaplaneGeom(J,prop);
aero = SeaplaneAero_Concept4(J,geom);

AR = geom.AR;
span_limit_ft = J.rfp_performance_requirements.maximum_wingspan_ft_strictly_below;
span_design_ft = span_limit_ft - A.span_design_margin_ft;
ws_limit = W*AR/span_limit_ft^2;
ws_design = W*AR/span_design_ft^2;

range = J.constraints.wing_loading_range_psf;
N = max(250,round(J.constraints.wing_loading_points));
WS = linspace(range(1),range(2),N)';
S = W./WS;
span = sqrt(AR*S);

wp_climb_SL = nan(N,1);
wp_climb_10k = nan(N,1);
wp_cruise = nan(N,1);
wp_oei_ideal = nan(N,1);
required_motor_hp = nan(N,1);

continuous = prop.motor_continuous_fraction;
margin = 1+A.motor_power_margin_fraction;
samples = A.design_constraint_speed_samples;

for k = 1:N
    geom.S_ref = S(k);
    cruise = constraint_cruise_speed_C4(W,S(k),10000,180,aero,prop.eta_p_cruise);
    climbSL = c4_required_climb_hp(W,S(k),0,2000,aero,prop.eta_p_climb,samples);
    climb10 = c4_required_climb_hp(W,S(k),10000,500,aero,prop.eta_p_climb,samples);

    if isempty(cruise) || isempty(climbSL) || isempty(climb10)
        continue
    end

    powerSL = climbSL.hp/continuous*margin;
    power10 = climb10.hp/continuous*margin;
    powerCruise = cruise.hp/continuous*margin;

    wp_climb_SL(k) = W/powerSL;
    wp_climb_10k(k) = W/power10;
    wp_cruise(k) = W/powerCruise;
    required_motor_hp(k) = max([powerSL,power10,powerCruise]);

    oei = c4_required_climb_hp(W,S(k),0,450,aero,prop.eta_p_climb,samples);
    if ~isempty(oei) && prop.n_motors > 1
        powerOEI = oei.hp/continuous*margin*prop.n_motors/(prop.n_motors-1);
        wp_oei_ideal(k) = W/powerOEI;
    end
end

wp_boundary = min([wp_climb_SL,wp_climb_10k,wp_cruise],[],2);
screened = WS >= ws_design & span < span_limit_ft & isfinite(wp_boundary);
if ~any(screened)
    error('C4:ConstraintDiagram','No valid AEO constraint points meet the design span bound.');
end

ids = find(screened);
[best_wp,local_idx] = max(wp_boundary(ids));
selected_idx = ids(local_idx);
selected_WS = WS(selected_idx);
selected_S = S(selected_idx);
selected_hp = required_motor_hp(selected_idx);
selected_span = span(selected_idx);

reference_S = J.sizing.S_ref_guess_ft2;
reference_hp = J.sizing.P_SL_guess_hp;
reference_WS = W/reference_S;
reference_wp = W/reference_hp;
reference_bound = interp1(WS,wp_boundary,reference_WS,'linear',NaN);
if isfinite(reference_bound) && reference_WS >= ws_design && reference_wp <= reference_bound
    reference_status = 'Within modeled AEO motor-power screen';
else
    reference_status = 'Outside modeled AEO motor-power screen';
end

values = [wp_climb_SL;wp_climb_10k;wp_cruise;wp_oei_ideal;reference_wp];
values = values(isfinite(values));
ymax = max(25,5*ceil(1.15*max(values)/5));

fig = figure('Color','w','Name','Concept 4 Constraint Diagram', ...
    'Position',[70 70 1450 820]);
ax = axes('Parent',fig,'Position',[0.085 0.19 0.87 0.72]);
hold(ax,'on');

hShade = patch(ax,[WS(ids);flipud(WS(ids))], ...
    [zeros(numel(ids),1);flipud(wp_boundary(ids))],[0.70 0.88 0.58], ...
    'FaceAlpha',0.63,'EdgeColor','none');

hSL = plot(ax,WS,wp_climb_SL,'Color',[0.08 0.22 0.95], ...
    'LineWidth',1.9);
h10 = plot(ax,WS,wp_climb_10k,'Color',[0.00 0.62 0.20], ...
    'LineWidth',1.9);
hCruise = plot(ax,WS,wp_cruise,'Color',[0.02 0.55 0.87], ...
    'LineWidth',2.0);
hOEI = plot(ax,WS,wp_oei_ideal,'--','Color',[0.85 0.23 0.17], ...
    'LineWidth',1.4);
hBound = plot(ax,WS,wp_boundary,'k-','LineWidth',2.4);

hSpanRFP = plot(ax,[ws_limit ws_limit],[0 ymax],':', ...
    'Color',[0.56 0.56 0.56],'LineWidth',1.35);
hSpanDesign = plot(ax,[ws_design ws_design],[0 ymax],'--', ...
    'Color',[0.36 0.36 0.36],'LineWidth',1.8);

hReference = plot(ax,reference_WS,reference_wp,'p', ...
    'MarkerSize',15,'MarkerFaceColor',[1.00 0.86 0.16], ...
    'MarkerEdgeColor','k','LineWidth',1.4);
hSelected = plot(ax,selected_WS,best_wp,'kx', ...
    'MarkerSize',11,'LineWidth',2.3);

xlabel(ax,'Wing loading W_{TO}/S (lbf/ft^2)','FontSize',12);
ylabel(ax,'Motor power loading W_{TO}/P_{motor,SL} (lbf/shp)','FontSize',12);
title(ax,{'Concept 4 Series-Hybrid Amphibian Mission Constraint Diagram', ...
    '12,500-lb team weight target - preliminary AEO electric-motor screen'}, ...
    'FontSize',14,'FontWeight','bold');
xlim(ax,range);
ylim(ax,[0 ymax]);
grid(ax,'on');
ax.GridAlpha = 0.19;
ax.FontSize = 11;
ax.Layer = 'top';

legend(ax,[hShade hSL h10 hCruise hOEI hBound hSpanDesign hSpanRFP hReference hSelected], ...
    {'Screened AEO region (motor + span ONLY)', ...
    '2,000-fpm climb at sea level', ...
    '500-fpm climb at 10,000 ft', ...
    '180-KTAS cruise at 10,000 ft', ...
    '450-fpm motor-out, optimistic / NOT verified', ...
    'Governing AEO motor-power boundary', ...
    '64-ft design-span margin', ...
    '65-ft strict RFP span boundary', ...
    'Initial 12,500-lb sizing guess', ...
    'Minimum rated motor-power point'}, ...
    'Location','northeast','FontSize',9,'Box','on');

reference_label = sprintf([ ...
    'Concept 4 initial point (NOT weight-closed)\n' ...
    'W/S = %.2f lbf/ft^2\n' ...
    'W/P = %.2f lbf/shp\n' ...
    'S = %.0f ft^2; motor rating = %.0f shp\n' ...
    '%s'],reference_WS,reference_wp,reference_S,reference_hp,reference_status);
annotation(fig,'textbox',[0.55 0.43 0.31 0.15], ...
    'String',reference_label,'FontSize',10,'BackgroundColor','w', ...
    'EdgeColor',[0.74 0.74 0.74],'FitBoxToText','on');

annotation(fig,'textbox',[0.09 0.035 0.85 0.095], ...
    'String',{ ...
    'Shading: numerical cruise + climb + motor continuous-rating + 64-ft span-margin screens only.', ...
    'NOT VERIFIED: water takeoff/landing over 50 ft, battery-only operating power, OEI drag/yaw, generator/energy feasibility, or 12,500-lb mass closure.'}, ...
    'EdgeColor','none','FontSize',9,'Color',[0.34 0.34 0.34]);

folder = fullfile(root,'results','constraints_12500');
if ~isfolder(folder), mkdir(folder); end
image_path = fullfile(folder,'concept4_mission_constraint_diagram.png');
fig_path = fullfile(folder,'concept4_mission_constraint_diagram.fig');
exportgraphics(fig,image_path,'Resolution',220);
savefig(fig,fig_path);

T = table(WS,S,span,wp_climb_SL,wp_climb_10k,wp_cruise, ...
    wp_oei_ideal,wp_boundary,required_motor_hp,screened, ...
    'VariableNames',{'WS_psf','S_ft2','span_ft', ...
    'WP_2000fpm_SL','WP_500fpm_10k','WP_180KTAS_10k', ...
    'WP_motor_out_optimistic','WP_AEO_limit','Required_motor_rating_hp', ...
    'Screened_region'});
writetable(T,fullfile(folder,'concept4_matching_diagram_data.csv'));

out = struct('weight_lb',W,'reference_WS_psf',reference_WS, ...
    'reference_WP_lb_per_hp',reference_wp,'reference_status',reference_status, ...
    'minimum_motor_point_WS_psf',selected_WS, ...
    'minimum_motor_point_S_ft2',selected_S, ...
    'minimum_motor_point_span_ft',selected_span, ...
    'minimum_motor_point_rating_hp',selected_hp, ...
    'minimum_motor_point_WP_lb_per_hp',best_wp, ...
    'span_design_WS_psf',ws_design,'span_RFP_WS_psf',ws_limit, ...
    'status','PRELIMINARY_AEO_MOTOR_AND_SPAN_SCREEN_ONLY', ...
    'image_file',image_path,'table',T);

fprintf('Concept 4 preliminary diagram at %.0f lb\n',W);
fprintf('Reference point: W/S %.2f, W/P %.2f; %s\n', ...
    reference_WS,reference_wp,reference_status);
fprintf('Minimum motor-power point: W/S %.2f, S %.1f ft^2, span %.2f ft\n', ...
    selected_WS,selected_S,selected_span);
fprintf('Minimum modeled electric motor nameplate: %.1f shp\n',selected_hp);
fprintf('Strict 65-ft span requires W/S > %.3f; 64-ft design margin requires W/S >= %.3f\n', ...
    ws_limit,ws_design);
fprintf('NOT a full RFP compliance or 12,500-lb weight-closure result.\n');
fprintf('Saved figure: %s\n',image_path);
end
