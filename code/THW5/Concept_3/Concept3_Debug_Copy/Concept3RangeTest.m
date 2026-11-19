classdef Concept3RangeTest < matlab.unittest.TestCase
 methods(Test)
  function correctedMissionAndPayload(t)
   o=ttpa_disciplines();c=find(string({o.miss.segments.type})=="cruise");
   t.verifyEqual(o.wts.payload(),2430);
   t.verifyEqual(o.miss.segments(c).distance_nm*1.150779448,1000,AbsTol=1e-8);
   t.verifyEqual(o.miss.segments(c).alt_ft,10000);
   t.verifyEqual(sum([o.miss.segments.time_min]),45);
   t.verifyGreaterThan(o.wts.OEW_breakdown(12490).landing_gear,0);
  end
  function ledgerAndWaterEmissions(t)
   o=ttpa_disciplines();r=concept3_mission_energy(12490,o,CheckLimits=false);
   electric=[r.trace.electric_only];
   t.verifyEqual(sum([r.trace(electric).fuel_lb]),0,AbsTol=1e-12);
   t.verifyEqual(r.fuel_lb,sum([r.trace.fuel_lb]),AbsTol=1e-8);
   t.verifyEqual(r.segment_weight_lb(1)-r.segment_weight_lb(end),r.fuel_lb,AbsTol=1e-6);
   dt=[r.trace.duration_min]/60;
   storedChange=sum(([r.trace.battery_charge_kw]*o.prop.eta_battery_charge ...
    -[r.trace.battery_discharge_kw]/o.prop.eta_battery_discharge).*dt);
   t.verifyEqual((r.final_SOC-r.initial_SOC)*o.prop.battery_capacity_kwh*o.mission_assumptions.capacity_retention, ...
    storedChange,AbsTol=1e-8);
   t.verifyGreaterThan(r.peak_discharge_kw,500);
   t.verifyFalse(r.feasible);
  end
  function insufficientHardwareCannotClaimRange(t)
   o=ttpa_disciplines();
   t.verifyError(@()concept3_mission_energy(12490,o),'C3:MissionInfeasible');
   r=run_concept3_range(WriteResults=false,DistanceStepMi=1000,MaximumRangeMi=1000,WeightStepLb=5000);
   t.verifyEqual(r.status,'NO_FEASIBLE_RANGE_ON_DECLARED_GRID');
   t.verifyTrue(isnan(r.maximum_range_statute_mi));
   t.verifyEqual(r.payload_lb,2430);
  end
  function generatorAndMotorRatingsAreIndependent(t)
   o=ttpa_disciplines();p=o.prop;before=p.generator_available_bus_kw(10000);m=p.installed_mass_breakdown();
   p.P_SL=2*p.P_SL;after=p.installed_mass_breakdown();
   t.verifyEqual(p.generator_available_bus_kw(10000),before,AbsTol=1e-8);
   t.verifyEqual(after.turboshafts_lb,m.turboshafts_lb,AbsTol=1e-8);
   t.verifyEqual(after.motors_lb,2*m.motors_lb,AbsTol=1e-8);
  end
  function depletedPackAndInvalidInitialSOC(t)
   o=ttpa_disciplines();o.prop.battery_capacity_kwh=1;
   r=concept3_mission_energy(12490,o,CheckLimits=false);
   t.verifyFalse(r.feasible);t.verifyLessThan(r.minimum_SOC,o.prop.battery_min_soc);
   t.verifyError(@()concept3_mission_energy(12490,o,InitialSOC=1.1),'C3:InitialSOC');
  end
  function sufficientSourcesCanPassEnergyLedger(t)
   o=ttpa_disciplines();o.prop.P_SL=1100;
   o.prop.generator_engine_shaft_power_sl_hp_each=500;
   o.prop.battery_max_discharge_bus_kw=800;
   r=concept3_mission_energy(12490,o,CheckLimits=false);
   t.verifyTrue(r.feasible);t.verifyGreaterThanOrEqual(r.minimum_SOC,o.prop.battery_min_soc);
   t.verifyLessThanOrEqual(r.peak_discharge_kw,800);
  end
 end
end
