function r=concept4_constraint_data(obj,J,A,n)
%CONCEPT4_CONSTRAINT_DATA Source-explicit flight sizing curves and water proxy.
if nargin<4,n=J.constraints.wing_loading_points;end
g=obj.geom;p=obj.prop;a=obj.aero;old=g.S_ref;restore=onCleanup(@() setArea(g,old));
W=J.analysis_design.evaluation_weight_lb;
domain=J.constraints.wing_loading_range_psf;
x=unique([linspace(domain(1),domain(2),n),W/old,W*g.AR/65^2]);m=numel(x);
motor=nan(5,m);generator=nan(3,m);shaft=nan(5,m);spans=nan(1,m);
for k=1:m
 g.S_ref=W/x(k);spans(k)=g.b;
 sl=c4_required_climb_hp(W,g.S_ref,0,2000,a,p.eta_p_climb,A.design_constraint_speed_samples);
 hi=c4_required_climb_hp(W,g.S_ref,10000,500,a,p.eta_p_climb,A.design_constraint_speed_samples);
 cr=constraint_cruise_speed_C4(W,g.S_ref,10000,180,a,p.eta_p_cruise);
 oe=c4_required_climb_hp(W,g.S_ref,0,450,a,p.eta_p_climb,A.design_constraint_speed_samples);
 ba=balkPower(W,a,p,J.constraint_plot.balked_landing_gradient);
 shaft(:,k)=[sl.hp;hi.hp;oe.hp;ba;cr.hp];
 factor=1+A.motor_power_margin_fraction;
 motor(:,k)=W./([sl.hp/p.motor_continuous_fraction;hi.hp/p.motor_continuous_fraction; ...
  oe.hp/p.motor_continuous_fraction*p.n_motors/(p.n_motors-1);ba;cr.hp/p.motor_continuous_fraction]*factor);
 alt=[0,10000,10000];powers=[sl.hp,hi.hp,cr.hp];share=[1-J.propulsion.phi.climb,1-J.propulsion.phi.climb,1];
 for j=1:3
  available=p.generator_available_bus_kw(alt(j))/(p.engine_shaft_power_sl_hp_each*p.n_generators);
  totalRating=p.motor_bus_kw(powers(j))*share(j)/available*(1+A.generator_power_margin_fraction);
  generator(j,k)=W/totalRating;
 end
end
env=min(motor([1,2,4,5],:),[],1);spanWall=W*g.AR/65^2;
c=J.constraint_plot.water_landing;air=(c.obstacle_height_ft-c.flare_entry_height_ft)/tand(c.approach_angle_deg)+c.flare_distance_ft;
assert(air<c.target_distance_ft,'C4:WaterProxy','Airborne distance exceeds landing target.');
atm=isa_atmosphere_C4(0);v2=2*c.effective_deceleration_g*32.174*(c.target_distance_ft-air)/c.touchdown_speed_over_stall^2;
water=.5*atm.rho_slug_ft3*a.CLmax_landing*v2/c.landing_beta;
r=struct('WS',x,'motor_limits',motor,'generator_limits',generator,'required_shaft_hp',shaft, ...
 'flight_envelope',env,'generator_envelope',min(generator,[],1),'span_ft',spans,'span_wall_psf',spanWall, ...
 'water_wall_psf',water,'water_airborne_and_flare_ft',air,'water_proxy',c,'plot_settings',J.constraint_plot, ...
 'reference',struct('W_lb',W,'S_ft2',old,'span_ft',sqrt(g.AR*old),'WS',W/old,'WP',W/p.P_SL, ...
 'motor_hp',p.P_SL,'generator_total_hp',p.n_generators*p.engine_shaft_power_sl_hp_each, ...
 'generator_WP',W/(p.n_generators*p.engine_shaft_power_sl_hp_each)), ...
 'source','OpenVSP wing-only virtual sizing family, fixed body/tail/float/pod geometry', ...
 'water_takeoff_distance_verified',false,'generator_loss_endurance_verified',false, ...
 'motor_out_drag_yaw_verified',false,'full_feasibility_shading',false);
end
function hp=balkPower(W,a,p,gradient)
at=isa_atmosphere_C4(0);cl=a.CLmax_landing;vs=sqrt(2*W/(at.rho_slug_ft3*a.geom.S_ref*cl))/1.687809857;
v=linspace(1.2*vs,max(180,1.2*vs+45),35);hp=Inf;
for speed=v
 f=a.flight_forces(W,speed,0,'landing_flaps_gear_up');
 if ~f.CL_limit_exceeded,hp=min(hp,(f.drag_lb+W*gradient)*speed*1.687809857/(550*p.eta_p_climb));end
end
end
function setArea(g,S),g.S_ref=S;end
