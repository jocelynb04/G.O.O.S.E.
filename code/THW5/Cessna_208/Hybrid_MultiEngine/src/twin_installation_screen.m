function screen=twin_installation_screen(config,weight)
%TWIN_INSTALLATION_SCREEN Geometric clearances and steady climb power.
i=config.installation;
h=config.hybrid;
p=grand_caravan_ex_params();
aircraft=ttpa_disciplines();
power=AMPH570Powertrain(h);
geometry=jsondecode(fileread(ttpa_requirements_path()));
body=geometry.geometry.fuselage;
for field={'engine_station_ft','propeller_diameter_ft_assumed','nosecone_length_ft','nosecone_max_diameter_ft'}
    validateattributes(i.(field{1}),{'numeric'},{'scalar','positive','finite'});
end
for field={'nosecone_mass_lb','wing_reinforcement_lb','nose_equipment_lb','feathered_prop_and_trim_CD0_increment'}
    validateattributes(i.(field{1}),{'numeric'},{'scalar','nonnegative','finite'});
end
validateattributes(i.net_drag_CD0_increment,{'numeric'},{'scalar','finite'});
validateattributes(i.usable_volume_fraction,{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
assert(i.engine_station_ft<p.span_ft/2,'TwinHybrid:EngineStation','Engine station must fall inside the wing semispan.');
assert(i.nosecone_max_diameter_ft<=body.width_ft,'TwinHybrid:NoseDiameter','Nosecone diameter must fit the inherited fuselage width.');
screen.engine_stations_ft=[-i.engine_station_ft i.engine_station_ft];
screen.propeller_diameter_ft=i.propeller_diameter_ft_assumed;
screen.propeller_fuselage_gap_ft=i.engine_station_ft-(body.width_ft+i.propeller_diameter_ft_assumed)/2;
screen.nosecone_length_ft=i.nosecone_length_ft;
screen.nosecone_diameter_ft=i.nosecone_max_diameter_ft;
screen.nose_usable_ft3=i.usable_volume_fraction*pi*(i.nosecone_max_diameter_ft/2)^2*i.nosecone_length_ft/3;
screen.fuselage_width_ft=body.width_ft;
screen.fuselage_length_behind_nose_ft=p.length_ft-body.nose_length_ft;
screen.wing_span_ft=p.span_ft;
screen.wing_area_ft2=aircraft.geom.S_ref;
screen.nominal_takeoff_shp=2*min(h.combined_peak_hp,h.propeller_max_shaft_hp);
screen.battery_capacity_total_kWh=2*h.battery_capacity_kWh;
% Fresh-pack boost limit at sea level for the full assumed burst duration.
usable_kWh=h.battery_capacity_kWh*(h.initial_soc-h.minimum_soc);
bus_kW=min(h.battery_capacity_kWh*h.battery_max_discharge_C, ...
    usable_kWh*3600/h.peak_duration_limit_s_assumed);
efficiency=h.motor_efficiency*h.inverter_efficiency*h.gearbox_efficiency;
electric_hp=min(h.motor_max_shaft_kW,max(0,bus_kW-h.hotel_load_kW)*efficiency)/.745699872;
screen.pack_limited_takeoff_shp=min(screen.nominal_takeoff_shp, ...
    2*(power.combustion_available_hp(get_state(0))+electric_hp));

altitude=[0;10000;0;10000];
engines=[2;2;1;1];
required=zeros(4,1);
available=required;
roc=required;
yaw=required;
gamma=3;
for k=1:numel(altitude)
    state=get_state(altitude(k));
    polar=aircraft.aero.drag_polar(state);
    CD0=polar.CD0+i.net_drag_CD0_increment+ ...
        (engines(k)==1)*i.feathered_prop_and_trim_CD0_increment;
    assert(CD0>0,'TwinHybrid:Drag','Total parasite drag coefficient must be positive.');
    gradient=tand(gamma);
    CL=min(aircraft.aero.CLmax_clean-aircraft.aero.CL_stall_margin, ...
        (gradient+sqrt(gradient^2+12*polar.K1*CD0))/(2*polar.K1));
    speed=sqrt(2*weight*cosd(gamma)/(state.rho*screen.wing_area_ft2*CL));
    drag=weight*cosd(gamma)*(CD0+polar.K1*CL^2)/CL;
    eta=aircraft.prop.eta_p_climb;
    required(k)=(drag+weight*sind(gamma))*speed/(550*eta);
    available(k)=engines(k)*min([h.combined_continuous_hp,h.propeller_max_shaft_hp, ...
        power.combustion_available_hp(state)]);
    roc(k)=60*speed*sind(gamma);
    if engines(k)==1
        yaw(k)=available(k)*550*eta/speed*i.engine_station_ft;
    end
end
screen.climb_screen=table(altitude,engines,required,available,available-required,roc,yaw, ...
    required<=available,'VariableNames',{'Altitude_ft','OperatingEngines','Required_shp', ...
    'Available_shp','Margin_shp','TargetROC_fpm','OEIThrustYaw_lbf_ft','PowerPass'});
end
