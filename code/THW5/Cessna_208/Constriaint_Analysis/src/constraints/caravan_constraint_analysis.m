function r = caravan_constraint_analysis(c)
%CARAVAN_CONSTRAINT_ANALYSIS Conventional EX amphibian screening constraints, no hybrid.
obj=ttpa_disciplines(); p=grand_caravan_ex_params();
validateattributes(c.wing_loading_range_psf,{'numeric'},{'numel',2,'positive','finite','increasing'});
validateattributes(c.wing_loading_points,{'numeric'},{'scalar','integer','>=',50,'finite'});
validateattributes(c.max_installed_power_shp,{'numeric'},{'scalar','positive','finite'});
validateattributes(c.design_margin_fraction,{'numeric'},{'scalar','>=',0,'<',1,'finite'});
assert(numel(c.climb_altitudes_ft)==2,'Constraints:AltitudeCount','Supply two climb altitudes.');
validateattributes(c.cruise_speeds_ktas,{'numeric'},{'vector','positive','finite'});
WSref=p.MTOW_lb/p.S_ref_ft2;
[wall,water]=water_landing_wall(obj,c.water_landing);
WS=unique([linspace(c.wing_loading_range_psf(1),c.wing_loading_range_psf(2),c.wing_loading_points), ...
    WSref,wall,wall*(1-c.design_margin_fraction)]);
WS=WS(WS>=c.wing_loading_range_psf(1) & WS<=c.wing_loading_range_psf(2));
condition=struct('altitude_ft',0,'config',c.climb_configuration,'beta',c.climb_beta, ...
    'max_continuous',true,'oei',false,'power_setting',c.climb_power_setting, ...
    'requirement_type',c.climb_requirement_type);
if string(c.climb_requirement_type)=="angle", condition.angle_deg=c.climb_angle_deg;
else, condition.roc_fpm=c.climb_rates_fpm(1); end
for k=1:2
    condition.altitude_ft=c.climb_altitudes_ft(k);
    if string(c.climb_requirement_type)=="rate", condition.roc_fpm=c.climb_rates_fpm(k); end
    [climb(k,:),climbinfo(k)]=constraint_climb_path(WS,obj,condition); %#ok<AGROW>
end
b=condition; b.altitude_ft=c.balked_landing_altitude_ft; b.config=c.balked_landing_configuration;
b.beta=c.balked_landing_beta; b.max_continuous=false; b.power_setting=1;
b.requirement_type='angle'; b.angle_deg=atand(c.balked_landing_gradient);
[balked,balkinfo]=constraint_climb_path(WS,obj,b);
oei=condition; oei.altitude_ft=0; oei.oei=true;
[oeiWP,~]=constraint_climb_path(WS,obj,oei);
WPfloor=p.MTOW_lb/c.max_installed_power_shp;
r.settings=c; r.WS=WS; r.climb_limits=climb; r.climb_info=climbinfo;
r.balked_limit=balked; r.balked_info=balkinfo; r.oei_positive_climb_limit=oeiWP;
r.water=water; r.WS_water_wall=wall; r.power_loading_floor=WPfloor;
r.reference=struct('WS',WSref,'WP',p.MTOW_lb/p.P_SL_shp,'weight_lb',p.MTOW_lb,'power_shp',p.P_SL_shp);
for k=1:2
    r.reference.required_climb_roc_fpm(k)=interp1(WS,climbinfo(k).roc_fpm,WSref);
    r.reference.climb_speed_ktas(k)=interp1(WS,climbinfo(k).V_fps,WSref)*3600/6076.11549;
end
for k=1:numel(c.cruise_speeds_ktas)
    con=struct('name','Cruise capability','type','cruise_speed','altitude_ft',c.cruise_altitude_ft, ...
        'distance_ft',NaN,'G',NaN,'ktas',c.cruise_speeds_ktas(k),'power_index',NaN, ...
        'config','clean','beta',c.cruise_beta,'oei',false,'max_continuous',true, ...
        'power_setting',c.cruise_power_setting,'method','drag_based','propeller_stopped',false);
    tmp=obj; tmp.cons=con;
    [cruise,ci]=constraint_cruise_speed(WS,tmp,1);
    cruise(ci.CL>obj.aero.CLmax_clean-obj.aero.CL_stall_margin)=0;
    envelope=min([climb;balked;cruise],[],1);
    valid=WS<=wall & envelope>=WPfloor;
    if c.require_powered_oei, envelope=min(envelope,oeiWP); valid=valid & envelope>=WPfloor; end
    candidateWP=(1-c.design_margin_fraction)*envelope;
    candidate=valid & WS<=wall*(1-c.design_margin_fraction) & candidateWP>=WPfloor;
    margin_applied=true;
    if ~any(candidate), candidate=valid; candidateWP=envelope; margin_applied=false; end
    selected=struct('exists',false,'WS',NaN,'WP',NaN,'S_ft2',NaN,'P_shp',NaN,'margin_applied',false);
    if any(candidate)
        score=candidateWP; score(~candidate)=-Inf; [bestWP,j]=max(score);
        selected=struct('exists',true,'WS',WS(j),'WP',bestWP,'S_ft2',p.MTOW_lb/WS(j), ...
            'P_shp',p.MTOW_lb/bestWP,'margin_applied',margin_applied);
    end
    candidate_design=selected;
    exceeds_benchmark=con.ktas>p.max_cruise_ktas;
    if exceeds_benchmark, selected.exists=false; end % Candidate is not supported by reference performance data.
    cap=interp1(WS,[climb;balked;cruise]',WSref)';
    reference_checks=r.reference.WP<=cap & WSref<=wall;
    row=struct('speed_ktas',con.ktas,'cruise_limit',cruise,'cruise_info',ci, ...
        'envelope',envelope,'numerical_feasible_mask',valid,'feasible_mask',valid & ~exceeds_benchmark, ...
        'candidate',candidate_design,'selected',selected, ...
        'above_published_cruise_benchmark',con.ktas>p.max_cruise_ktas, ...
        'reference_power_checks',reference_checks,'reference_meets_aeo_constraints',all(reference_checks), ...
        'reference_speed_supported_by_published_benchmark',~exceeds_benchmark, ...
        'reference_cruise_power_required_shp',p.MTOW_lb/interp1(WS,cruise,WSref)*ci.kP, ...
        'reference_cruise_power_available_shp',p.P_SL_shp*ci.kP);
    if k==1, r.cases=row; else, r.cases(k)=row; end
end
% Comparison band: meets the comparison speed and shared AEO constraints, fails target speed.
if isfield(c,'plot_comparison_cruise_ktas')
    it=find([r.cases.speed_ktas]==c.plot_required_cruise_ktas,1);
    ic=find([r.cases.speed_ktas]==c.plot_comparison_cruise_ktas,1);
    assert(~isempty(it) && ~isempty(ic),'Constraints:ComparisonSpeed','Both plotted speeds must be calculated.');
    low=r.cases(it).envelope; high=r.cases(ic).envelope;
    r.comparison_band=struct('required_ktas',c.plot_required_cruise_ktas, ...
        'comparison_ktas',c.plot_comparison_cruise_ktas,'lower_WP',low,'upper_WP',high, ...
        'mask',WS<=wall & high>low & low>0, ...
        'interpretation',"Meets comparison-speed and common AEO constraints but fails target-speed constraint; same frozen aircraft polar.");
end
% Single-engine OEI: no shaft power. Glide is a separate unpowered aerodynamic check.
state=get_state(0); cfg=obj.aero.get_config_polar(state,struct('config','clean','propeller_stopped',true));
CL=min(sqrt(cfg.CD0/cfg.K1),cfg.CLmax-obj.aero.CL_stall_margin);
CD=cfg.CD0+cfg.K1*CL^2; gamma=atan(CD/CL);
V=sqrt(2*WSref*cos(gamma)/(state.rho*CL));
r.oei_glide=struct('positive_powered_climb_possible',false,'CL',CL,'LD',CL/CD, ...
    'glide_angle_deg',rad2deg(gamma),'best_glide_ktas',V*3600/6076.11549, ...
    'sink_fpm',60*V*sin(gamma),'stopped_propeller_drag_is_assumed',true);
r.all_constraints_including_positive_oei_feasible=false;
r.selection_objective="Largest W/P (least required installed power at reference MTOW), with requested curve/wall margin if possible.";
end
