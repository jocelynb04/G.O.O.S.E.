classdef Concept4OpenVSPTest < matlab.unittest.TestCase
 properties
  Obj
  J
  A
  Summary
  Flight
  Data
 end
 methods(TestClassSetup)
  function initialize(t)
   [t.Obj,t.J,t.A]=concept4_context();
   [t.Summary,t.Flight]=concept4_size_at_weight(t.Obj,t.J,t.A);
   t.Data=concept4_constraint_data(t.Obj,t.J,t.A,11);
  end
 end
 methods(Test)
  function nativeGeometryAgreement(t)
   report=verify_openvsp_geometry(false);
   t.verifyTrue(report.all_pass);t.verifyEqual(height(report.checks),24);
   t.verifyEqual(t.Obj.geom.S_ref,325,AbsTol=1e-8);
   t.verifyEqual(t.Obj.geom.b,64,AbsTol=1e-8);
   t.verifyEqual(t.Obj.geom.S_ht,62.868,AbsTol=1e-8);
   t.verifyEqual(t.Obj.geom.S_vt,61.3731,AbsTol=1e-8);
  end
  function physicalCopiesNotSymmetryBox(t)
   t.verifyEqual(t.Obj.geom.float_data.beam_ft,4,AbsTol=1e-6);
   t.verifyEqual(t.Obj.geom.pod_data.diameter_ft,4/3,AbsTol=1e-5);
   t.verifyEqual(t.Obj.prop.n_motors,6);
   t.verifyEqual(t.J.geometry.openvsp.propellers.diameter_ft,4);
   t.verifyEqual(t.J.geometry.openvsp.propellers.blades,3);
  end
  function wingSweepKeepsOtherCadSurfacesFixed(t)
   [o,~,~]=concept4_context();before=o.geom.S_wet_fuselage;o.geom.S_ref=650;
   t.verifyEqual(o.geom.S_wet_wing,2*t.Obj.geom.S_wet_wing,AbsTol=1e-8);
   t.verifyEqual(o.geom.S_wet_fuselage,before,AbsTol=1e-8);
   t.verifyEqual(o.geom.S_ht,t.Obj.geom.S_ht,AbsTol=1e-8);
   t.verifyEqual(o.geom.S_wet_pontoons,t.Obj.geom.S_wet_pontoons,AbsTol=1e-8);
  end
  function nativeAreaReachesAeroModel(t)
   d=t.Obj.aero.drag_breakdown();
   t.verifyEqual(d.components.wing.S_wet_ft2,t.Obj.geom.S_wet_wing,AbsTol=1e-8);
   t.verifyEqual(d.components.pontoons.S_wet_ft2,512.116307020087,AbsTol=1e-8);
   t.verifyGreaterThan(d.CD0_total,0);
   t.verifyEqual(t.Obj.geom.S_wet,2101.55414133438,AbsTol=1e-5);
  end
  function actualFloatVolumeReachesHydroModel(t)
   h=t.Obj.hydro.buoyancy_screen(12490);
   t.verifyEqual(h.external_float_volume_ft3,393.316907470337,AbsTol=1e-8);
   t.verifyEqual(h.rfp_below_cabin_floor_screen,'NOT_ASSESSED');
   t.verifyEqual(h.adjacent_compartments_flooding,'NOT_ASSESSED');
  end
  function massAndMissionAccounting(t)
   s=t.Summary;t.verifyEqual(s.payload_lb,2430);
   t.verifyEqual(s.modeled_mass_lb,s.modeled_OEW_lb+s.payload_lb+s.mission_fuel_lb,AbsTol=1e-6);
   t.verifyLessThan(s.evaluation_weight_lb,12500);
   t.verifyFalse(s.rfp_compliance_established);t.verifyFalse(s.fully_coupled_mass_closure);
   t.verifyLessThanOrEqual(s.peak_mission_battery_kw,s.battery_bus_capability_kw);
  end
  function reserveAndElectricWaterPhases(t)
   rows=t.Flight.segments;electric=ismember(string({rows.phase}),["taxi","takeoff","landing"]);
   loiter=strcmp({rows.phase},'loiter');
   t.verifyEqual(sum([rows(loiter).duration_min]),45,AbsTol=1e-9);
   t.verifyEqual(sum([rows(electric).fuel_burn_lb]),0,AbsTol=1e-8);
   t.verifyEqual(t.Flight.total_fuel_lb,sum([rows.fuel_burn_lb]),AbsTol=1e-6);
  end
  function normalizedEnvelopeAndReference(t)
   r=t.Data;
   t.verifyEqual(r.flight_envelope,min(r.motor_limits([1,2,4,5],:),[],1),AbsTol=1e-10);
   t.verifyEqual(r.reference.WS,12490/325,AbsTol=1e-10);
   t.verifyEqual(r.reference.WP,12490/t.Summary.motor_total_nameplate_hp,AbsTol=1e-10);
   t.verifyEqual(t.Obj.geom.S_ref,325,AbsTol=1e-8);t.verifyFalse(r.full_feasibility_shading);
  end
  function landingAndFailureLimitsStayExplicit(t)
   r=t.Data;
   t.verifyLessThan(r.water_wall_psf,r.reference.WS);
   t.verifyGreaterThan(r.water_airborne_and_flare_ft,0);
   t.verifyFalse(r.water_takeoff_distance_verified);t.verifyFalse(r.generator_loss_endurance_verified);
   t.verifyFalse(r.motor_out_drag_yaw_verified);
  end
 end
end
