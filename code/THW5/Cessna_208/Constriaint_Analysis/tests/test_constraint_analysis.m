function tests=test_constraint_analysis
tests=functiontests(localfunctions);
end
function [c,o]=inputs()
root=setup_project(); c=jsondecode(fileread(fullfile(root,'config','Constraint_analysis.json'))); o=ttpa_disciplines();
% Additional speeds are test fixtures only; default runtime remains Caravan164KTAS.
c.cruise_speeds_ktas=[180 164 165]; c.plot_required_cruise_ktas=180; c.plot_comparison_cruise_ktas=165;
end
function testAnglePowerAndLiftBalance(t)
[~,o]=inputs(); x=[20 32 45]; con=struct('altitude_ft',10000,'config','clean','beta',1, ...
    'max_continuous',true,'oei',false,'power_setting',1,'requirement_type','angle','angle_deg',3);
[wp,a]=constraint_climb_path(x,o,con); W=9062; S=W./x; st=get_state(10000); q=.5*st.rho*a.V_fps.^2;
verifyEqual(t,q.*S*a.CL,W*cosd(3)*ones(size(x)),'RelTol',1e-12);
P=W./wp*a.kP; D=q.*S*a.CD;
verifyEqual(t,550*a.eta_p*P-D.*a.V_fps,W*a.V_fps*sind(3),'RelTol',1e-12);
verifyEqual(t,a.roc_fpm,60*a.V_fps*sind(3),'RelTol',1e-12);
end
function testClimbAltitudeAndCruiseOrdering(t)
[c,~]=inputs(); r=caravan_constraint_analysis(c);
verifyTrue(t,all(r.climb_limits(2,:)<r.climb_limits(1,:)));
verifyTrue(t,all(r.cases(1).cruise_limit<r.cases(2).cruise_limit));
end
function testOEIFailureAndGlide(t)
[c,~]=inputs(); r=caravan_constraint_analysis(c);
verifyEqual(t,r.oei_positive_climb_limit,zeros(size(r.WS)));
verifyGreaterThan(t,r.oei_glide.LD,0); verifyGreaterThan(t,r.oei_glide.sink_fpm,0);
c.require_powered_oei=true; r=caravan_constraint_analysis(c);
verifyFalse(t,any(r.cases(2).feasible_mask)); verifyFalse(t,r.cases(2).selected.exists);
end
function testSelectionSatisfiesMargins(t)
[c,~]=inputs(); r=caravan_constraint_analysis(c); s=r.cases(2).selected;
verifyTrue(t,s.exists); verifyTrue(t,s.margin_applied);
verifyLessThanOrEqual(t,s.WS,(1-c.design_margin_fraction)*r.WS_water_wall+1e-9);
verifyLessThanOrEqual(t,s.WP,(1-c.design_margin_fraction)*interp1(r.WS,r.cases(2).envelope,s.WS)+1e-9);
verifyLessThanOrEqual(t,s.P_shp,c.max_installed_power_shp+1e-9);
end
function testPublishedSpeedDistinguishedFromEquations(t)
[c,~]=inputs(); r=caravan_constraint_analysis(c);
verifyTrue(t,r.cases(1).above_published_cruise_benchmark);
verifyFalse(t,r.cases(1).selected.exists);
verifyFalse(t,r.cases(1).reference_speed_supported_by_published_benchmark);
verifyTrue(t,r.cases(2).reference_speed_supported_by_published_benchmark);
verifyTrue(t,r.cases(2).reference_meets_aeo_constraints);
end
function testWaterProxyAndDistanceSensitivity(t)
[c,o]=inputs(); [wall,a]=water_landing_wall(o,c.water_landing);
verifyEqual(t,a.reference_model_distance_ft,c.water_landing.reference_total_distance_ft,'AbsTol',1e-8);
verifyGreaterThan(t,a.effective_deceleration_g,0);
c.water_landing.target_total_distance_ft=1800; shorter=water_landing_wall(o,c.water_landing);
verifyLessThan(t,shorter,wall);
end
function testImpossibleLandingDistance(t)
[c,o]=inputs(); c.water_landing.target_total_distance_ft=500;
verifyError(t,@() water_landing_wall(o,c.water_landing),'Constraints:LandingDistance');
end
function testRateMode(t)
[~,o]=inputs(); con=struct('altitude_ft',0,'config','clean','beta',1, ...
    'max_continuous',true,'oei',false,'power_setting',1,'requirement_type','rate','roc_fpm',500);
a=constraint_climb_path(32,o,con); con.roc_fpm=1000;
[b,info]=constraint_climb_path(32,o,con); verifyLessThan(t,b,a); verifyEqual(t,info.roc_fpm,1000);
end
function testSmallEngineHasNoRegion(t)
[c,~]=inputs(); c.max_installed_power_shp=50; r=caravan_constraint_analysis(c);
verifyFalse(t,any(r.cases(2).feasible_mask)); verifyFalse(t,r.cases(2).selected.exists);
end
function testCruisePowerBalance(t)
[c,~]=inputs(); r=caravan_constraint_analysis(c);
for k=1:numel(r.cases)
    a=r.cases(k); req=r.reference.weight_lb/interp1(r.WS,a.cruise_limit,r.reference.WS)*a.cruise_info.kP;
    verifyEqual(t,a.reference_cruise_power_required_shp,req,'RelTol',1e-12);
    verifyEqual(t,a.reference_meets_aeo_constraints,all(a.reference_power_checks));
end
end

function testSpeedComparisonBand(t)
[c,~]=inputs(); r=caravan_constraint_analysis(c); b=r.comparison_band;
verifyEqual(t,b.required_ktas,180); verifyEqual(t,b.comparison_ktas,165);
verifyTrue(t,any(b.mask));
j=find(b.mask,1,'last'); middle=(b.lower_WP(j)+b.upper_WP(j))/2;
verifyGreaterThan(t,middle,r.cases(1).envelope(j));
comparison=find([r.cases.speed_ktas]==165,1);
verifyLessThan(t,middle,r.cases(comparison).envelope(j));
verifyLessThanOrEqual(t,r.WS(j),r.WS_water_wall);
end

function testCaravanOnlyDefaults(t)
root=setup_project(); c=jsondecode(fileread(fullfile(root,'config','Constraint_analysis.json')));
r=caravan_constraint_analysis(c);
verifyEqual(t,[r.cases.speed_ktas],164); verifyEqual(t,c.plot_required_cruise_ktas,164);
verifyFalse(t,isfield(r,'comparison_band')); verifyEqual(t,r.reference.WS,9062/279,'AbsTol',1e-10);
verifyEqual(t,r.reference.WP,9062/867,'AbsTol',1e-10);
end

function testCourseLandingCLAndCruiseAltitude(t)
root=setup_project(); c=jsondecode(fileread(fullfile(root,'config','Constraint_analysis.json')));
J=jsondecode(fileread(ttpa_requirements_path())); original=jsondecode(fileread(fullfile(root,'docs','archive','Original_IHW3.json')));
verifyEqual(t,J.aerodynamics.CLmax_landing,original.aerodynamics.CLmax_landing);
verifyEqual(t,J.aerodynamics.CLmax_landing,2.2); verifyEqual(t,c.cruise_altitude_ft,10000);
s=json_as_struct_array(J.missions.std_mission.segments); i=find(string({s.type})=="cruise",1);
verifyEqual(t,s(i).alt_ft,10000); verifyEqual(t,s(i-1).alt_ft,10000);
end
