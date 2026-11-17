function out = run_concept4_constraints_12500()
root = fileparts(mfilename('fullpath'));
J = jsondecode(fileread(fullfile(root,'concept4_aero_hydro_requirements.json')));
A = jsondecode(fileread(fullfile(root,'Concept4_integration_assumptions.json')));
W = 12500;
P = SeaplaneProp_Concept4(J);
G = SeaplaneGeom(J,P);
D = SeaplaneAero_Concept4(J,G);
AR = G.AR;
span_rfp = J.rfp_performance_requirements.maximum_wingspan_ft_strictly_below;
span_design = span_rfp - A.span_design_margin_ft;
ws_span_rfp = W*AR/span_rfp^2;
ws_span_design = W*AR/span_design^2;
ws_limits = J.constraints.wing_loading_range_psf;
ws_min = max(ws_limits(1),ws_span_design);
ws_max = ws_limits(2);
if ws_min >= ws_max
    error('C4:Constraints','No wing-loading range satisfies the span design limit.');
end
N = max(50,round(J.constraints.wing_loading_points));
WS = linspace(ws_min,ws_max,N)';
S = W./WS;
span = sqrt(AR*S);
cruise_hp = nan(N,1);
climb_sl_hp = nan(N,1);
climb_10k_hp = nan(N,1);
oei_ideal_hp = nan(N,1);
motor_cruise_hp = nan(N,1);
motor_climb_sl_hp = nan(N,1);
motor_climb_10k_hp = nan(N,1);
motor_required_hp = nan(N,1);
generator_required_hp = nan(N,1);
valid = false(N,1);
f_cont = P.motor_continuous_fraction;
eta_gen_chain = P.eta_generator*P.eta_rectifier;
eta_gen_cont = P.generator_continuous_fraction;
phi_climb = J.propulsion.phi.climb;
motor_margin = 1 + A.motor_power_margin_fraction;
generator_margin = 1 + A.generator_power_margin_fraction;
kw_per_hp = 0.7456998715822702;
for k = 1:N
    G.S_ref = S(k);
    c = constraint_cruise_speed_C4(W,S(k),10000,180,D,P.eta_p_cruise);
    c0 = c4_required_climb_hp(W,S(k),0,2000,D,P.eta_p_climb,A.design_constraint_speed_samples);
    c10 = c4_required_climb_hp(W,S(k),10000,500,D,P.eta_p_climb,A.design_constraint_speed_samples);
    if isempty(c) || isempty(c0) || isempty(c10)
        continue
    end
    cruise_hp(k) = c.hp;
    climb_sl_hp(k) = c0.hp;
    climb_10k_hp(k) = c10.hp;
    motor_cruise_hp(k) = c.hp/f_cont*motor_margin;
    motor_climb_sl_hp(k) = c0.hp/f_cont*motor_margin;
    motor_climb_10k_hp(k) = c10.hp/f_cont*motor_margin;
    motor_required_hp(k) = max([motor_cruise_hp(k),motor_climb_sl_hp(k),motor_climb_10k_hp(k)]);
    bus_cruise = P.motor_bus_kw(c.hp);
    bus_climb_sl = P.motor_bus_kw(c0.hp)*(1-phi_climb);
    bus_climb_10k = P.motor_bus_kw(c10.hp)*(1-phi_climb);
    gen_cruise = bus_cruise/(eta_gen_chain*eta_gen_cont*kw_per_hp*P.sigma_isa(10000)^P.generator_lapse_exponent*P.n_generators);
    gen_climb_sl = bus_climb_sl/(eta_gen_chain*eta_gen_cont*kw_per_hp*P.sigma_isa(0)^P.generator_lapse_exponent*P.n_generators);
    gen_climb_10k = bus_climb_10k/(eta_gen_chain*eta_gen_cont*kw_per_hp*P.sigma_isa(10000)^P.generator_lapse_exponent*P.n_generators);
    generator_required_hp(k) = max([gen_cruise,gen_climb_sl,gen_climb_10k])*generator_margin;
    oe = c4_required_climb_hp(W,S(k),0,450,D,P.eta_p_climb,A.design_constraint_speed_samples);
    if ~isempty(oe)
        oei_ideal_hp(k) = oe.hp/f_cont*P.n_motors/(P.n_motors-1)*motor_margin;
    end
    valid(k) = span(k)<span_rfp;
end
T = table(WS,S,span,cruise_hp,climb_sl_hp,climb_10k_hp, ...
    motor_cruise_hp,motor_climb_sl_hp,motor_climb_10k_hp, ...
    motor_required_hp,generator_required_hp,oei_ideal_hp,valid, ...
    'VariableNames',{'WS_psf','S_ft2','span_ft','cruise_shaft_hp', ...
    'climb_2000_shaft_hp','climb_500_shaft_hp','motor_cruise_rated_hp', ...
    'motor_climb_2000_rated_hp','motor_climb_500_rated_hp', ...
    'motor_required_rated_hp','generator_required_engine_hp', ...
    'oei_idealized_rated_hp','span_screen'});
valid_idx = find(valid & isfinite(motor_required_hp) & isfinite(generator_required_hp));
if isempty(valid_idx)
    error('C4:Constraints','No preliminary cruise/climb point passed the screens.');
end
[~,ii] = min(motor_required_hp(valid_idx));
selected_idx = valid_idx(ii);
selected = T(selected_idx,:);
folder = fullfile(root,'results','constraints_12500');
if ~isfolder(folder)
    mkdir(folder)
end
writetable(T,fullfile(folder,'constraint_sweep_12500.csv'));
f1 = figure('Name','Concept 4 matching diagram: electric motor rating');
plot(WS,motor_cruise_hp,'LineWidth',1.5)
hold on
plot(WS,motor_climb_sl_hp,'LineWidth',1.5)
plot(WS,motor_climb_10k_hp,'LineWidth',1.5)
plot(WS,motor_required_hp,'k','LineWidth',2.2)
plot(WS,oei_ideal_hp,'--','LineWidth',1)
plot(WS(selected_idx),motor_required_hp(selected_idx),'ko','MarkerFaceColor','k','HandleVisibility','off')
xline(ws_span_design,':','64-ft design span','HandleVisibility','off')
xlabel('Wing loading W/S (lb/ft^2)')
ylabel('Required installed electric motor peak rating (hp)')
title('Concept 4: Preliminary matching constraints at 12,500 lb')
legend('180 KTAS, 10,000 ft','ROC 2000 fpm, MSL', ...
    'ROC 500 fpm, 10,000 ft','Governing AEO motor rating', ...
    'OEI idealized ONLY, excludes failure drag/yaw','Location','best')
grid on
saveas(f1,fullfile(folder,'motor_matching_12500.png'));
f2 = figure('Name','Concept 4 matching diagram: motor power loading');
plot(WS,W./motor_required_hp,'k','LineWidth',2)
hold on
plot(WS(selected_idx),W/motor_required_hp(selected_idx),'ko','MarkerFaceColor','k')
xline(ws_span_design,':','64-ft design span','HandleVisibility','off')
xlabel('Wing loading W/S (lb/ft^2)')
ylabel('Motor power loading W/P (lb/hp)')
title('Concept 4: Preliminary electric motor W/P at 12,500 lb')
grid on
saveas(f2,fullfile(folder,'motor_power_loading_12500.png'));
f3 = figure('Name','Concept 4: turbogenerator rating');
plot(WS,generator_required_hp,'LineWidth',1.6)
hold on
plot(WS(selected_idx),generator_required_hp(selected_idx),'ko','MarkerFaceColor','k')
xline(ws_span_design,':','64-ft design span','HandleVisibility','off')
xlabel('Wing loading W/S (lb/ft^2)')
ylabel('Required engine shaft rating per generator (hp)')
title('Concept 4: Preliminary turbogenerator rating at 12,500 lb')
grid on
saveas(f3,fullfile(folder,'generator_rating_12500.png'));
out = struct('weight_lb',W,'status','PRELIMINARY_CRUISE_CLIMB_SPAN_ONLY', ...
    'selected_minimum_motor_rating',selected,'wing_loading_from_strict_span_psf',ws_span_rfp, ...
    'wing_loading_from_design_span_psf',ws_span_design,'candidates',T, ...
    'note','Motor minimum is not a mass-optimal or RFP-feasible final design. Water takeoff/landing, battery, OEI and 12500-lb mass closure remain unverified.');
fprintf('Fixed comparison weight: %.0f lb\n',W)
fprintf('Span design bound: W/S >= %.3f lb/ft^2\n',ws_span_design)
fprintf('Minimum motor-rating point: W/S = %.2f lb/ft^2, S = %.2f ft^2, span = %.2f ft\n', ...
    selected.WS_psf,selected.S_ft2,selected.span_ft)
fprintf('Motor nameplate rating: %.1f hp\n',selected.motor_required_rated_hp)
fprintf('Turbogenerator engine rating: %.1f hp\n',selected.generator_required_engine_hp)
fprintf('NOT VERIFIED: battery-only water takeoff, water landing, OEI failed-prop yaw/drag, 12500-lb mass closure\n')
fprintf('Results: %s\n',folder)
end
