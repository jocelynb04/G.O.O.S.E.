function r = concept3_mission_energy(W_TO,obj,options)
%CONCEPT3_MISSION_ENERGY Explicit series-hybrid phase fuel/SOC accounting.
% Electrical-only phases forbid generator operation. No ground charging.
% Constants are preliminary schedules in JSON, not validated water performance.
arguments
 W_TO (1,1) double {mustBePositive,mustBeFinite}
 obj (1,1) struct
 options.CheckLimits (1,1) logical = true
 options.InitialSOC (1,1) double = NaN
end
A=obj.mission_assumptions;p=obj.prop;profile=obj.miss;
soc=p.battery_initial_soc;if isfinite(options.InitialSOC),soc=options.InitialSOC;end
assert(soc>=p.battery_min_soc && soc<=p.battery_max_soc,'C3:InitialSOC','Initial SOC outside limits.');
energy=p.battery_capacity_kwh*A.capacity_retention;
assert(energy>0,'C3:Capacity','Battery usable capacity must be positive.');
W=W_TO;rows=struct([]);fuel=zeros(1,numel(profile.segments));weights=W_TO;
reasons=strings(0,1);elapsed=0;peakDischarge=0;peakCharge=0;
for k=1:numel(profile.segments)
 s=profile.segments(k);kind=string(s.type);h=s.alt_ft;cfg='clean';eta=p.eta_p_climb;
 electric=any(kind==["taxi","takeoff","approach","balked_landing","landing"]);
 roc=0;v=A.climb_ktas;
 switch kind
  case 'taxi',duration=A.taxi_min;hp=A.taxi_hp;v=0;
  case 'takeoff',duration=A.takeoff_min;hp=A.takeoff_hp;v=0;
  case 'landing',duration=A.landing_min;hp=A.landing_hp;v=0;
  case 'climb'
   h0=0;if k>1,h0=profile.segments(k-1).alt_ft;end
   roc=A.climb_fpm;duration=(h-h0)/roc;hp=NaN;
  case 'balked_landing'
   h0=0;if k>1,h0=profile.segments(k-1).alt_ft;end
   roc=A.balked_climb_fpm;v=A.approach_ktas;duration=(h-h0)/roc;hp=NaN;cfg='landing_flaps_gear_up';
  case 'cruise',v=s.ktas;duration=60*s.distance_nm/v;hp=NaN;eta=p.eta_p_cruise;
  case 'loiter',v=s.ktas;duration=s.time_min;hp=NaN;eta=p.eta_p_loiter;
  case {'descent','approach'}
   h0=0;if k>1,h0=profile.segments(k-1).alt_ft;end
   roc=-A.descent_fpm;if kind=="approach",roc=-A.approach_fpm;v=A.approach_ktas;cfg='landing_flaps_gear_up';end
   duration=(h-h0)/roc;hp=NaN;
  otherwise,error('C3:Segment','Unsupported mission phase %s.',kind);
 end
 assert(duration>=0 && isfinite(duration),'C3:Duration','Invalid phase duration.');
 n=max(1,ceil(duration/A.step_min));
 for j=1:n
  dt=duration/n/60;alt=h;
  if any(kind==["climb","balked_landing","descent","approach"]),alt=h0+(h-h0)*(j-.5)/n;end
  state=get_state(alt);CL=NaN;required=hp;
  if isnan(required)
   V=v*6076.11549/3600;q=.5*state.rho*V^2;CL=W/(q*obj.geom.S_ref);
   con=struct('config',cfg,'propeller_stopped',false);
   polar=obj.aero.get_config_polar(state,con);
   required=max(0,(q*obj.geom.S_ref*(polar.CD0+polar.K1*CL^2)*V+W*roc/60)/(550*eta));
   if CL>obj.aero.get_CLmax(state,con),reasons(end+1)=kind+": stall";end %#ok<AGROW>
  end
  rating=p.P_SL*p.motor_continuous_fraction;
  if any(kind==["takeoff","balked_landing"]),rating=p.P_SL;end
  if required>rating+1e-7,reasons(end+1)=kind+": motor rating";end %#ok<AGROW>
  demand=p.motor_bus_kw(required)+A.accessory_kw;
  available=0;if ~electric,available=p.generator_available_bus_kw(alt);end
  discharge=max(0,demand-available);charge=0;gen=min(available,demand);
  if ~electric && available>demand && dt>0
   charge=min([available-demand,p.battery_max_charge_bus_kw, ...
    max(0,p.battery_max_soc-soc)*energy/(p.eta_battery_charge*dt)]);
   gen=gen+charge;
  end
  batteryMass=p.battery_mass_lb()/2.20462262;
  busLimit=min(p.battery_max_discharge_bus_kw,batteryMass*p.battery_specific_power_kw_per_kg*p.eta_battery_discharge);
  if discharge>busLimit+1e-7,reasons(end+1)=kind+": battery power";end %#ok<AGROW>
  if gen>0 && soc<=p.battery_min_soc+1e-10 && discharge>0
   reasons(end+1)=kind+": generator sustained-power shortfall"; %#ok<AGROW>
  end
  before=soc;soc=soc+(charge*p.eta_battery_charge-discharge/p.eta_battery_discharge)*dt/energy;
  if soc<p.battery_min_soc-1e-8,reasons(end+1)=kind+": battery SOC floor";end %#ok<AGROW>
  used=gen/(.745699872*p.eta_generator*p.eta_rectifier)*p.BSFC*dt;
  W=W-used;fuel(k)=fuel(k)+used;elapsed=elapsed+dt*60;
  peakDischarge=max(peakDischarge,discharge);peakCharge=max(peakCharge,charge);
  row=struct('phase',kind,'time_min',elapsed,'duration_min',dt*60,'alt_ft',alt, ...
   'shaft_hp',required,'generator_bus_kw',gen,'battery_discharge_kw',discharge,'battery_charge_kw',charge, ...
   'soc_start',before,'soc_end',soc,'fuel_lb',used,'weight_lb',W,'electric_only',electric,'CL',CL);
  if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
 end
 weights(end+1)=W; %#ok<AGROW>
end
r=struct('feasible',isempty(reasons),'reasons',unique(reasons),'fuel_lb',sum(fuel), ...
 'fuel_by_phase_lb',fuel,'segment_weight_lb',weights,'initial_SOC',rows(1).soc_start, ...
 'final_SOC',soc,'minimum_SOC',min([rows.soc_end]),'peak_discharge_kw',peakDischarge, ...
 'peak_charge_kw',peakCharge,'elapsed_min',elapsed,'trace',rows,'validated_water_performance',false);
assert(abs(W_TO-W-sum(fuel))<1e-6,'C3:Ledger','Fuel ledger does not balance.');
if options.CheckLimits && ~r.feasible,error('C3:MissionInfeasible','%s',strjoin(r.reasons,'; '));end
end
