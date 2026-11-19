function [s,flight]=concept4_size_at_weight(obj,J,A)
%CONCEPT4_SIZE_AT_WEIGHT Fixed CAD geometry and explicit 12,490-lb budget.
W=J.analysis_design.evaluation_weight_lb;p=obj.prop;g=obj.geom;a=obj.aero;
assert(W<J.analysis_design.maximum_certificated_takeoff_weight_exclusive_lb,'C4:WeightCeiling','Evaluation weight must be below 12500 lb.');
sl=c4_required_climb_hp(W,g.S_ref,0,2000,a,p.eta_p_climb,A.design_constraint_speed_samples);
hi=c4_required_climb_hp(W,g.S_ref,10000,500,a,p.eta_p_climb,A.design_constraint_speed_samples);
cr=constraint_cruise_speed_C4(W,g.S_ref,10000,180,a,p.eta_p_cruise);
assert(~isempty(sl)&&~isempty(hi)&&~isempty(cr),'C4:Constraints','No valid flight power solution.');
p.P_SL=max([sl.hp,hi.hp,cr.hp])/p.motor_continuous_fraction*(1+A.motor_power_margin_fraction);
p.P_SL=max(p.P_SL,A.ground_phases.takeoff.shaft_hp);
p.engine_shaft_power_sl_hp_each=1;
genSL=p.generator_available_bus_kw(0);genHi=p.generator_available_bus_kw(10000);
share=J.propulsion.phi.climb;
p.engine_shaft_power_sl_hp_each=max([p.motor_bus_kw(cr.hp)/genHi, ...
 (1-share)*p.motor_bus_kw(sl.hp)/genSL,(1-share)*p.motor_bus_kw(hi.hp)/genHi])*(1+A.generator_power_margin_fraction);
p.battery_installed_mass_kg=[];
probe=obj.mission.run(W,'std_mission',true);
p.battery_capacity_kwh=max(A.minimum_battery_capacity_kwh, ...
 probe.peak_cumulative_pack_deficit_kwh/(p.battery_initial_soc-p.battery_min_soc)*(1+A.battery_energy_margin_fraction));
flight=obj.mission.run(W,'std_mission',false);
energykg=p.battery_capacity_kwh/J.propulsion.battery_specific_energy_kwh_per_kg;
powerkg=1.1*flight.peak_battery_discharge_bus_kw/(p.eta_battery_discharge*J.propulsion.battery_specific_power_kw_per_kg);
battkg=max(energykg,powerkg);p.battery_installed_mass_kg=battkg;
flight=obj.mission.run(W,'std_mission',false);
bd=obj.weights.OEW_breakdown(W);P=J.weights.propulsion_integration;
factor=1+P.wiring_fraction_of_prop_mass+P.heat_sink_thermal_fraction_of_prop_mass+P.cowl_nacelle_fraction_of_prop_mass ...
 +P.struts_mounting_fraction_of_prop_mass+P.spinner_fraction_of_prop_mass;
oew=bd.total-(bd.prop_battery-battkg*2.20462262185)*factor;
gross=oew+obj.weights.payload()+flight.total_fuel_lb;
s=struct('status','FIXED_WEIGHT_BUILDUP_SCREEN_ONLY','geometry_source_sha256',J.geometry.openvsp.source.sha256, ...
 'evaluation_weight_lb',W,'wing_area_ft2',g.S_ref,'span_ft',g.b,'aspect_ratio',g.AR, ...
 'motor_total_nameplate_hp',p.P_SL,'generator_engine_hp_each',p.engine_shaft_power_sl_hp_each, ...
 'generator_count',p.n_generators,'battery_nameplate_kWh',p.battery_capacity_kwh,'battery_mass_lb',battkg*2.20462262185, ...
 'battery_bus_capability_kw',p.battery_discharge_limit_bus_kw(),'peak_mission_battery_kw',flight.peak_battery_discharge_bus_kw, ...
 'mission_final_SOC',flight.soc_end,'modeled_OEW_lb',oew,'payload_lb',obj.weights.payload(), ...
 'mission_fuel_lb',flight.total_fuel_lb,'modeled_mass_lb',gross,'margin_to_12490_lb',W-gross, ...
 'mass_budget_pass',gross<=W,'fully_coupled_mass_closure',false,'rfp_compliance_established',false, ...
 'required_2000fpm_shaft_hp',sl.hp,'required_500fpm_shaft_hp',hi.hp,'required_180kt_shaft_hp',cr.hp);
end
