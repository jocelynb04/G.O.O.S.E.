function [WSmax,info] = water_landing_wall(obj,c)
%WATER_LANDING_WALL Over-50-ft approach/flare plus constant-deceleration WATER PROXY.
% No runway ground-roll correlation is used. Reference calibration is not validation.
for key={'target_total_distance_ft','reference_total_distance_ft','obstacle_height_ft', ...
        'flare_horizontal_distance_ft_assumed','touchdown_speed_over_stall_assumed'}
    validateattributes(c.(key{1}),{'numeric'},{'scalar','positive','finite'});
end
validateattributes(c.approach_angle_deg,{'numeric'},{'scalar','>',0,'<',30,'finite'});
validateattributes(c.flare_entry_height_ft,{'numeric'},{'scalar','>=',0,'<',c.obstacle_height_ft,'finite'});
validateattributes(c.landing_beta,{'numeric'},{'scalar','>',0,'<=',1,'finite'});
validateattributes(c.reference_landing_beta,{'numeric'},{'scalar','>',0,'<=',1,'finite'});
validateattributes(c.deceleration_sensitivity_fraction,{'numeric'},{'scalar','>=',0,'<',1,'finite'});
p=grand_caravan_ex_params(); st=get_state(c.altitude_ft); ref=get_state(c.reference_altitude_ft);
con=struct('config','landing_flaps_gear_up'); CLmax=obj.aero.get_CLmax(st,con);
airborne=(c.obstacle_height_ft-c.flare_entry_height_ft)/tand(c.approach_angle_deg)+ ...
    c.flare_horizontal_distance_ft_assumed;
assert(c.target_total_distance_ft>airborne && c.reference_total_distance_ft>airborne, ...
    'Constraints:LandingDistance','Total landing distance must exceed the assumed airborne/flare distance.');
reference_Vs2=2*c.reference_landing_beta*(p.MTOW_lb/p.S_ref_ft2)/(ref.rho*CLmax);
if string(c.method)=="reference_calibrated_surrogate"
    a=c.touchdown_speed_over_stall_assumed^2*reference_Vs2/(2*(c.reference_total_distance_ft-airborne));
elseif string(c.method)=="assumed_deceleration"
    validateattributes(c.effective_deceleration_g_assumed,{'numeric'},{'scalar','positive','finite'});
    a=c.effective_deceleration_g_assumed*32.174;
else
    error('Constraints:LandingMethod','Choose reference_calibrated_surrogate or assumed_deceleration.');
end
max_Vs2=2*a*(c.target_total_distance_ft-airborne)/c.touchdown_speed_over_stall_assumed^2;
WSmax=.5*st.rho*CLmax*max_Vs2/c.landing_beta;
info=struct('method',string(c.method),'airborne_and_flare_ft',airborne, ...
    'water_run_budget_ft',c.target_total_distance_ft-airborne,'effective_deceleration_fps2',a, ...
    'effective_deceleration_g',a/32.174,'CLmax',CLmax,'WS_limit_psf',WSmax, ...
    'WS_sensitivity_range_psf',WSmax*[1-c.deceleration_sensitivity_fraction,1+c.deceleration_sensitivity_fraction], ...
    'reference_model_distance_ft',airborne+c.touchdown_speed_over_stall_assumed^2*reference_Vs2/(2*a));
end
