function r=twin_constraint_analysis(config,ref)
% Evaluate a fixed polar and weight while sweeping wing and power loadings.
mission=twin_hybrid_mission(config);
assert(mission.feasible,'TwinHybrid:ConstraintMission', ...
    'The constraint analysis needs a completed mission for landing weight. %s',mission.failure);
W=mission.initial_weight_lb;
installation=twin_installation_screen(config,W);
aircraft=ttpa_disciplines();
h=config.hybrid;
train=AMPH570Powertrain(h);
betaLanding=mission.final_weight_lb/W;
Ppeak=installation.pack_limited_takeoff_shp;
WSref=W/installation.wing_area_ft2;
WPref=W/Ppeak;
wall=water_limit(aircraft,ref.water_landing,betaLanding);
range=ref.wing_loading_range_psf;
WS=unique([linspace(range(1),range(2),ref.wing_loading_points),WSref,wall]);
WS=WS(WS>=range(1) & WS<=range(2));
j=find(WS==WSref,1);
assert(~isempty(j),'TwinHybrid:WingLoading','Reference wing loading falls outside the chart range.');

% With fixed polar and target angle, optimum CL is constant and power scales with sqrt(W/S).
climb=installation.climb_screen;
required=climb.Required_shp.*sqrt(WS/WSref);
available=climb.Available_shp;
labels=["3° AEO climb, sea level";"3° AEO climb, 10,000 ft"; ...
    "3° OEI climb, sea level";"3° OEI climb, 10,000 ft"];

balk=get_state(ref.balked_landing_altitude_ft);
gamma=atand(ref.balked_landing_gradient);
polar=aircraft.aero.get_config_polar(balk,struct('config',ref.balked_landing_configuration, ...
    'propeller_stopped',false));
CD0=polar.CD0+config.installation.net_drag_CD0_increment;
CL=min(polar.CLmax-aircraft.aero.CL_stall_margin, ...
    (tand(gamma)+sqrt(tand(gamma)^2+12*polar.K1*CD0))/(2*polar.K1));
V=sqrt(2*betaLanding*WS*cosd(gamma)/(balk.rho*CL));
required(5,:)=W*betaLanding*V*(cosd(gamma)*(CD0+polar.K1*CL^2)/CL+sind(gamma)) ...
    /(550*aircraft.prop.eta_p_climb);
available(5,1)=continuous_power(train,balk);
labels(5,1)=compose('Balked landing (%g%% gradient, continuous)',100*ref.balked_landing_gradient);

segments=json_as_struct_array(config.segments);
cruise=segments(find(string({segments.type})=="cruise",1));
state=get_state(cruise.alt_ft);
polar=aircraft.aero.drag_polar(state);
speeds=[cruise.ktas;ref.cruise_speeds_ktas(:)];
for k=1:numel(speeds)
    row=5+k;
    V=speeds(k)*6076.11549/3600;
    q=.5*state.rho*V^2;
    CL=ref.cruise_beta*WS/q;
    CD=polar.CD0+config.installation.net_drag_CD0_increment+polar.K1*CL.^2;
    required(row,:)=q*(W./WS).*CD*V/(550*aircraft.prop.eta_p_cruise);
    required(row,CL>aircraft.aero.CLmax_clean-aircraft.aero.CL_stall_margin)=Inf;
    available(row,1)=continuous_power(train,state);
    labels(row,1)=compose('%g KTAS at %g ft',speeds(k),cruise.alt_ft);
end

limits=W/Ppeak*available./required;
envelope=min(limits(1:6,:),[],1);
feasible=WS<=wall & WPref<=envelope;
r=struct('WS',WS,'WS_range',range,'limits',limits,'envelope',envelope, ...
    'feasible_mask',feasible,'water_wall',wall,'primary_cruise_ktas',speeds(1));
r.reference=struct('WS',WSref,'WP',WPref,'weight_lb',W,'landing_weight_lb',mission.final_weight_lb, ...
    'peak_shp',Ppeak,'passes_primary_screen',feasible(j));
r.reference_power=table(labels,required(:,j),available,available-required(:,j), ...
    required(:,j)<=available,'VariableNames',{'Condition','Required_shp','Available_shp','Margin_shp','PowerPass'});
end

function hp=continuous_power(train,state)
h=train.config;
hp=2*min([h.combined_continuous_hp,h.propeller_max_shaft_hp,train.combustion_available_hp(state)]);
end

function wall=water_limit(aircraft,c,beta)
% Use the conventional calibrated deceleration with this mission's landing fraction.
assert(string(c.method)=="reference_calibrated_surrogate",'TwinHybrid:WaterMethod', ...
    'This analysis uses the reference-calibrated water proxy.');
p=grand_caravan_ex_params();
state=get_state(c.altitude_ft);
reference=get_state(c.reference_altitude_ft);
landing=struct('config','landing_flaps_gear_up');
airborne=(c.obstacle_height_ft-c.flare_entry_height_ft)/tand(c.approach_angle_deg) ...
    +c.flare_horizontal_distance_ft_assumed;
assert(min(c.target_total_distance_ft,c.reference_total_distance_ft)>airborne, ...
    'TwinHybrid:WaterDistance','Landing distance must exceed the approach and flare distance.');
wall=(p.MTOW_lb/p.S_ref_ft2)*(c.reference_landing_beta/beta) ...
    *(state.rho*aircraft.aero.get_CLmax(state,landing)) ...
    /(reference.rho*aircraft.aero.get_CLmax(reference,landing)) ...
    *(c.target_total_distance_ft-airborne)/(c.reference_total_distance_ft-airborne);
end
