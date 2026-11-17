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

% Approved conceptual screen only, not an RFP stall-speed requirement.
% Approximate 75 KIAS as KEAS at standard sea level; no IAS calibration.
landing_stall_kias = 75;
landing_stall_fps = landing_stall_kias*(6076.115485564304/3600);
landing_stall_rho = 0.002377; % slug/ft^3, assumed standard sea-level density
landing_stall_clmax = 2.2;
landing_weight_ratio = 1.0; % W_L / W_TO; water requirement is at MTOW
ws_landing_stall = 0.5*landing_stall_rho*landing_stall_fps^2 ...
    *landing_stall_clmax/landing_weight_ratio;

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

% Required nameplate power is the maximum demand, so allowable W/P is
% bounded ABOVE by the minimum of the individual W/P limits.
wp_boundary = min([wp_climb_SL,wp_climb_10k,wp_cruise],[],2);
span_screen = WS >= ws_design & span < span_limit_ft;
landing_stall_screen = WS <= ws_landing_stall;
screened = span_screen & landing_stall_screen & isfinite(wp_boundary);
if ~any(screened)
    error('C4:ConstraintDiagram','No valid AEO points meet the span and assumed stall screens.');
end

ids = find(screened);
[best_wp,local_idx] = max(wp_boundary(ids));
selected_idx = ids(local_idx);
selected_WS = WS(selected_idx);
selected_S = S(selected_idx);
selected_hp = required_motor_hp(selected_idx);
selected_span = span(selected_idx);

% Current coupled candidates use their OWN weight and total motor nameplate.
% They are context overlays, not pass/fail tests against fixed-weight curves.
candidate_area = [300;325;350];
candidate_weight = zeros(3,1);
candidate_motor = zeros(3,1);
candidate_span = zeros(3,1);
candidate_target = zeros(3,1);
candidate_source = strings(3,1);
for k = 1:3
    candidate_source(k) = fullfile('results', ...
        sprintf('fixedwing_%d',candidate_area(k)),'summary.json');
    candidate = jsondecode(fileread(fullfile(root,candidate_source(k))));
    fields = {'wing_area_ft2','weight_lb','motor_shaft_rating_hp', ...
        'wing_span_ft','team_weight_limit_lb'};
    for j = 1:numel(fields)
        validateattributes(candidate.(fields{j}),{'numeric'}, ...
            {'scalar','real','finite','positive'});
    end
    if ~candidate.converged || candidate.wing_area_ft2 ~= candidate_area(k)
        error('C4:CandidateSummary','Expected a converged %d-ft^2 summary.',candidate_area(k));
    end
    candidate_weight(k) = candidate.weight_lb;
    candidate_motor(k) = candidate.motor_shaft_rating_hp;
    candidate_span(k) = candidate.wing_span_ft;
    candidate_target(k) = candidate.team_weight_limit_lb;
end
candidate_WS = candidate_weight./candidate_area;
candidate_WP = candidate_weight./candidate_motor;
candidate_margin = candidate_target-candidate_weight;
C = table(candidate_area,candidate_weight,candidate_span,candidate_motor, ...
    candidate_target,candidate_margin,candidate_WS,candidate_WP,candidate_source, ...
    'VariableNames',{'wing_area_ft2','weight_lb','wing_span_ft', ...
    'motor_shaft_rating_hp','team_weight_target_lb','weight_margin_lb', ...
    'WS_actual_psf','WP_actual_lb_per_shp','source_summary'});

values = [wp_climb_SL;wp_climb_10k;wp_cruise;wp_oei_ideal;candidate_WP];
values = values(isfinite(values));
ymax = max(25,5*ceil(1.15*max(values)/5));

fig = figure('Color','w','Name','Concept 4 Constraint Diagram', ...
    'Position',[70 70 1280 900]);
ax = axes('Parent',fig,'Position',[0.09 0.34 0.87 0.55], ...
    'FontName','Times New Roman');
hold(ax,'on');

% Interpolate only patch endpoints so shading ends on the exact limits,
% without changing the validated cruise/climb calculation grid or curves.
shade_WS = unique([max(ws_design,WS(1));WS(ids);min(ws_landing_stall,WS(end))]);
shade_WP = interp1(WS,wp_boundary,shade_WS,'linear');
hShade = patch(ax,[shade_WS;flipud(shade_WS)], ...
    [zeros(numel(shade_WS),1);flipud(shade_WP)],[0.70 0.88 0.58], ...
    'FaceAlpha',0.32,'EdgeColor','none');

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
hLandingStall = plot(ax,[ws_landing_stall ws_landing_stall],[0 ymax],'--', ...
    'Color',[0.50 0.20 0.62],'LineWidth',1.8,'Tag','assumed_landing_stall_boundary');

hSelected = plot(ax,selected_WS,best_wp,'kx', ...
    'MarkerSize',11,'LineWidth',2.3);
colors = [0.10 0.35 0.75;0.05 0.48 0.35;0.80 0.15 0.12];
markers = {'o','s','^'};
hCandidate = gobjects(3,1);
for k = 1:3
    hCandidate(k) = plot(ax,candidate_WS(k),candidate_WP(k),markers{k}, ...
        'MarkerSize',10,'MarkerFaceColor',colors(k,:), ...
        'MarkerEdgeColor','k','LineWidth',1.1, ...
        'Tag',sprintf('candidate_%d',candidate_area(k)));
end

xlabel(ax,'Wing loading, W/S (lbf/ft^2)','FontSize',13);
ylabel(ax,'Motor power loading, W/P (lbf/shp)','FontSize',13);
title(ax,'Concept 4 preliminary matching diagram','FontSize',15);
subtitle(ax,'Background: 12,500 lb | Candidates: actual gross weight / installed total motor rating', ...
    'FontSize',11);
xlim(ax,[min(20,min(candidate_WS)-2),max(47,max(candidate_WS)+2)]);
ylim(ax,[min(6,min(candidate_WP)-0.7),max(20,max(candidate_WP)+2)]);
grid(ax,'on');
ax.GridAlpha = 0.14;
ax.FontSize = 12;
ax.Layer = 'top';
ax.Box = 'on';

% Offset labels and leader lines only; never displace the candidate markers.
label_x = [44;38.3;32.8];
label_y = 7.25;
for k = 1:3
    if candidate_margin(k) < 0
        label = sprintf('%d ft^2\nW = %.1f lb\n%.1f lb over team target', ...
            candidate_area(k),candidate_weight(k),-candidate_margin(k));
    else
        label = sprintf('%d ft^2\nW = %.1f lb',candidate_area(k),candidate_weight(k));
    end
    plot(ax,[candidate_WS(k),label_x(k)],[candidate_WP(k),label_y+0.12], ...
        '-','Color',colors(k,:),'LineWidth',0.7,'HandleVisibility','off');
    text(ax,label_x(k),label_y,label, ...
        'FontName','Times New Roman','FontSize',10.5, ...
        'HorizontalAlignment','center','VerticalAlignment','top', ...
        'Color',colors(k,:),'Tag',sprintf('candidate_label_%d',candidate_area(k)));
end

lgd = legend(ax,[hShade hSL h10 hCruise hOEI hBound hSpanDesign hSpanRFP hLandingStall hSelected hCandidate'], ...
    {sprintf('Preliminary screened region\n(includes assumed stall limit)'), ...
    '2,000-fpm climb at sea level', ...
    '500-fpm climb at 10,000 ft', ...
    '180-KTAS cruise at 10,000 ft', ...
    '450-fpm motor-out (unverified)', ...
    'Governing AEO motor-power boundary', ...
    '64-ft design-span margin', ...
    '65-ft strict RFP span boundary', ...
    'Assumed landing stall-speed screen (provisional)', ...
    'Minimum motor rating (screen only)', ...
    '300-ft^2 coupled candidate', ...
    '325-ft^2 coupled candidate', ...
    '350-ft^2 candidate (over team target)'}, ...
    'NumColumns',3,'FontName','Times New Roman','FontSize',10,'Box','off');
lgd.Position = [0.09 0.115 0.87 0.17];

annotation(fig,'textbox',[0.09 0.015 0.87 0.075], ...
    'String',{ ...
    'Preliminary SCREENED region, not verified aircraft feasibility. Actual-weight markers are not direct pass/fail tests against fixed-weight curves.', ...
    'UNVERIFIED: water takeoff/landing, battery-only operation, OEI drag/yaw, hardware and sustained power/energy. The stall limit is an assumption.'}, ...
    'EdgeColor','none','FontName','Times New Roman','FontSize',9.5,'Color',[0.25 0.25 0.25]);

folder = fullfile(root,'results','constraints_12500');
if ~isfolder(folder), mkdir(folder); end
image_path = fullfile(folder,'concept4_mission_constraint_diagram.png');
fig_path = fullfile(folder,'concept4_mission_constraint_diagram.fig');
exportgraphics(fig,image_path,'Resolution',300);
savefig(fig,fig_path);
final_folder = fullfile(root,'results','thw5_final');
if ~isfolder(final_folder), mkdir(final_folder); end
pdf_path = fullfile(final_folder,'constraint_screen_12500.pdf');
exportgraphics(fig,pdf_path,'ContentType','vector');

T = table(WS,S,span,wp_climb_SL,wp_climb_10k,wp_cruise, ...
    wp_oei_ideal,wp_boundary,required_motor_hp,screened, ...
    span_screen,landing_stall_screen,repmat(ws_design,N,1),repmat(ws_landing_stall,N,1), ...
    'VariableNames',{'WS_psf','S_ft2','span_ft', ...
    'WP_2000fpm_SL','WP_500fpm_10k','WP_180KTAS_10k', ...
    'WP_motor_out_optimistic','WP_AEO_limit','Required_motor_rating_hp', ...
    'Screened_region','Span_screen','Assumed_landing_stall_screen', ...
    'WS_min_design_span_psf','WS_max_assumed_landing_stall_psf'});
writetable(T,fullfile(folder,'concept4_matching_diagram_data.csv'));
candidate_path = fullfile(folder,'concept4_candidate_markers.csv');
writetable(C,candidate_path);

out = struct('weight_lb',W,'candidate_markers',C, ...
    'minimum_motor_point_WS_psf',selected_WS, ...
    'minimum_motor_point_S_ft2',selected_S, ...
    'minimum_motor_point_span_ft',selected_span, ...
    'minimum_motor_point_rating_hp',selected_hp, ...
    'minimum_motor_point_WP_lb_per_hp',best_wp, ...
    'span_design_WS_psf',ws_design,'span_RFP_WS_psf',ws_limit, ...
    'assumed_landing_stall_WS_max_psf',ws_landing_stall, ...
    'landing_stall_assumptions',struct('speed_kias',landing_stall_kias, ...
    'speed_fps',landing_stall_fps,'rho_slug_ft3',landing_stall_rho, ...
    'CLmax',landing_stall_clmax,'landing_to_takeoff_weight_ratio',landing_weight_ratio), ...
    'status','PRELIMINARY_AEO_MOTOR_SPAN_AND_ASSUMED_STALL_SCREEN', ...
    'image_file',image_path,'pdf_file',pdf_path, ...
    'candidate_data_file',candidate_path,'table',T);

fprintf('Concept 4 preliminary diagram at %.0f lb\n',W);
disp(C);
fprintf('Minimum motor-power point: W/S %.2f, S %.1f ft^2, span %.2f ft\n', ...
    selected_WS,selected_S,selected_span);
fprintf('Minimum modeled electric motor nameplate: %.1f shp\n',selected_hp);
fprintf('Strict 65-ft span requires W/S > %.3f; 64-ft design margin requires W/S >= %.3f\n', ...
    ws_limit,ws_design);
fprintf('NOT a full RFP compliance or 12,500-lb weight-closure result.\n');
fprintf('Assumed landing-stall screen: W/S <= %.9f lbf/ft^2; not an RFP stall-speed requirement or water-distance verification.\n', ...
    ws_landing_stall);
fprintf('Saved figure: %s\n',image_path);
end
