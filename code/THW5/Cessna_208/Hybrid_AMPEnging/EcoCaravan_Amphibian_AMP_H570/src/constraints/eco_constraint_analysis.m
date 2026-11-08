function r=eco_constraint_analysis(config_path)
%ECO_CONSTRAINT_ANALYSIS Screen the fixed-polar amphibian at the loaded mission weight.
c=jsondecode(fileread(config_path));
root=eco_project_root();
ref=jsondecode(fileread(fullfile(root,'docs','reference','CONVENTIONAL_CONSTRAINT_INPUTS.json')));
mission=eco_mission(config_path);
assert(mission.feasible,'EcoConstraints:Mission', ...
    'A complete mission is needed for landing weight and SOC. Stopped in %s: %s', ...
    mission.failure_segment,mission.failure);
aircraft=ttpa_disciplines();
train=AMPH570Powertrain(c.hybrid);
h=c.hybrid;
W=mission.initial_weight_lb;
betaLanding=mission.final_weight_lb/W;
Psl=min(h.combined_peak_hp,h.propeller_max_shaft_hp);
WSref=W/aircraft.geom.S_ref;
WPref=W/Psl;
[wall,water]=water_wall(aircraft,ref.water_landing,betaLanding);
WS=unique([linspace(ref.wing_loading_range_psf(1),ref.wing_loading_range_psf(2), ...
    ref.wing_loading_points),WSref,wall]);
WS=WS(WS>=ref.wing_loading_range_psf(1) & WS<=ref.wing_loading_range_psf(2));
j=find(WS==WSref,1);
assert(~isempty(j),'EcoConstraints:Reference','Loaded wing loading falls outside the sweep.');

climbAlt=ref.climb_altitudes_ft;
for k=1:numel(climbAlt)
    state=get_state(climbAlt(k));
    [climbWork(k,:),climbROC(k,:)]=climb_work(WS,aircraft,state, ...
        ref.climb_configuration,ref.climb_beta,ref.climb_angle_deg); %#ok<AGROW>
    climbAvailable(k)=continuous_power(train,state); %#ok<AGROW>
end
climb=(climbAvailable(:)/Psl)./climbWork;

balkState=get_state(ref.balked_landing_altitude_ft);
balkWork=climb_work(WS,aircraft,balkState,ref.balked_landing_configuration, ...
    betaLanding,atand(ref.balked_landing_gradient));
% Budget a fresh burst after the approach, with no charge or regen during it.
duration=h.peak_duration_limit_s_assumed;
usable_kWh=max(0,mission.final_soc-h.minimum_soc)*h.battery_capacity_kWh;
bus_kW=min(h.battery_capacity_kWh*h.battery_max_discharge_C,usable_kWh*3600/duration);
driveEfficiency=h.motor_efficiency*h.inverter_efficiency*h.gearbox_efficiency;
electricHP=min(h.motor_max_shaft_kW,max(0,bus_kW-h.hotel_load_kW)*driveEfficiency)/.745699872;
coreHP=train.combustion_available_hp(balkState);
boostHP=min(Psl,coreHP+electricHP);
fuelHP=continuous_power(train,balkState);
balked=(boostHP/Psl)./balkWork;
balkedFuel=(fuelHP/Psl)./balkWork;

cruiseCheck=eco_cruise_check(c,W);
state=get_state(cruiseCheck.Altitude_ft(1));
polar=aircraft.aero.drag_polar(state);
for k=1:height(cruiseCheck)
    V=cruiseCheck.Speed_KTAS(k)*6076.11549/3600;
    q=.5*state.rho*V^2;
    CL=ref.cruise_beta*WS/q;
    cruiseWork(k,:)=q*(polar.CD0+polar.K1*CL.^2)*V./ ...
        (550*aircraft.prop.eta_p_cruise*WS); %#ok<AGROW>
    cruise(k,:)=(cruiseCheck.Continuous_shp(k)/Psl)./cruiseWork(k,:); %#ok<AGROW>
    cruise(k,CL>aircraft.aero.CLmax_clean-aircraft.aero.CL_stall_margin)=0;
end

envelope=min([climb;balked;cruise(1,:)],[],1);
mask=WS<=wall & envelope>=WPref;
conditions=[compose('%g-deg climb at %g ft',repmat(ref.climb_angle_deg,numel(climbAlt),1),climbAlt(:)); ...
    "Balked landing (boost)"; "Balked landing (fuel only)"; ...
    compose('Cruise at %g KTAS',cruiseCheck.Speed_KTAS)];
required=W*[climbWork(:,j);balkWork(j);balkWork(j);cruiseWork(:,j)];
available=[climbAvailable(:);boostHP;fuelHP;cruiseCheck.Continuous_shp];
margin=available-required;
passes=margin>=0;
passes(end-height(cruiseCheck)+1:end)=cruiseCheck.Passes;
r.reference_power=table(conditions,required,available,margin,passes,'VariableNames', ...
    {'Condition','Required_shp','Available_shp','Margin_shp','Passes'});
r.reference=struct('WS',WSref,'WP',WPref,'weight_lb',W,'wing_area_ft2',aircraft.geom.S_ref, ...
    'peak_shp',Psl,'landing_weight_lb',mission.final_weight_lb,'landing_beta',betaLanding, ...
    'landing_SOC',mission.final_soc,'implied_climb_ROC_fpm',climbROC(:,j), ...
    'passes_primary_screen',mask(j),'passes_comparison_screen', ...
    mask(j) && all(WPref<=cruise(:,j)));
r.WS=WS;
r.WS_range=ref.wing_loading_range_psf;
r.climb_angle_deg=ref.climb_angle_deg;
r.climb_altitudes_ft=climbAlt;
r.balked_gradient=ref.balked_landing_gradient;
r.climb_limits=climb;
r.balked_limit=balked;
r.balked_fuel_limit=balkedFuel;
r.balked_burst_s=duration;
r.cruise_limits=cruise;
r.cruise_check=cruiseCheck;
r.envelope=envelope;
r.feasible_mask=mask;
r.water=water;
r.WS_water_wall=wall;
r.total_propulsion_loss_limit=zeros(size(WS));
r.combustion_loss_electric_upper_bound_shp=electricHP;
r.combustion_loss_electric_balk_margin_shp=electricHP-W*balkWork(j);
end

function hp=continuous_power(train,state)
h=train.config;
hp=min([train.combustion_available_hp(state),h.combined_continuous_hp,h.propeller_max_shaft_hp]);
end

function [work,roc]=climb_work(WS,aircraft,state,configuration,beta,angle)
% Minimum shaft power at fixed flight-path angle, with the inherited stall margin.
polar=aircraft.aero.get_config_polar(state,struct('config',configuration,'propeller_stopped',false));
G=tand(angle);
CL=min(polar.CLmax-aircraft.aero.CL_stall_margin, ...
    (G+sqrt(G^2+12*polar.K1*polar.CD0))/(2*polar.K1));
CD=polar.CD0+polar.K1*CL^2;
V=sqrt(2*beta*WS*cosd(angle)/(state.rho*CL));
work=beta*V*(cosd(angle)*CD/CL+sind(angle))/(550*aircraft.prop.eta_p_climb);
roc=60*V*sind(angle);
end

function [wall,info]=water_wall(aircraft,c,beta)
% Transfer the conventional calibration with the same floats and full-flap polar.
assert(string(c.method)=="reference_calibrated_surrogate",'EcoConstraints:WaterMethod', ...
    'This chart uses the conventional reference-calibrated water proxy.');
p=grand_caravan_ex_params();
state=get_state(c.altitude_ft);
refState=get_state(c.reference_altitude_ft);
config=struct('config','landing_flaps_gear_up');
CLmax=aircraft.aero.get_CLmax(state,config);
refCLmax=aircraft.aero.get_CLmax(refState,config);
airborne=(c.obstacle_height_ft-c.flare_entry_height_ft)/tand(c.approach_angle_deg) + ...
    c.flare_horizontal_distance_ft_assumed;
waterRun=c.target_total_distance_ft-airborne;
refRun=c.reference_total_distance_ft-airborne;
assert(waterRun>0 && refRun>0,'EcoConstraints:WaterDistance', ...
    'Total distance must exceed the approach and flare distance.');
refTouchdown2=c.touchdown_speed_over_stall_assumed^2* ...
    2*c.reference_landing_beta*(p.MTOW_lb/p.S_ref_ft2)/(refState.rho*refCLmax);
a=refTouchdown2/(2*refRun);
wall=state.rho*CLmax*a*waterRun/(beta*c.touchdown_speed_over_stall_assumed^2);
info=struct('airborne_and_flare_ft',airborne,'water_run_budget_ft',waterRun, ...
    'CLmax',CLmax,'effective_deceleration_g',a/32.174,'landing_beta',beta);
end
