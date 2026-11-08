function tests=test_hybrid
tests=functiontests(localfunctions);
end
function [c,o]=inputs()
root=fileparts(fileparts(mfilename('fullpath')));
J=jsondecode(fileread(fullfile(root,'config','Hybrid_requirements.json'))); c=J.hybrid; o=ttpa_disciplines();
end
function testBatteryMass(t)
[c,~]=inputs(); p=HybridPowertrain(c);
verifyEqual(t,p.battery_mass_lb,c.battery_capacity_kWh*1000/c.battery_specific_energy_Wh_per_kg*2.20462262185,'RelTol',1e-12);
end
function testElectricLedger(t)
[c,o]=inputs(); p=HybridPowertrain(c); E=p.energy_kWh;
a=p.step(100,get_state(0),'electric',0,.1,o.prop);
verifyEqual(t,a.fuel_lb,0); verifyEqual(t,a.turbine_hp,0);
expected=(100*.745699872/(c.motor_efficiency*c.inverter_efficiency*c.gearbox_efficiency)+c.hotel_load_kW)*.1;
verifyEqual(t,E-p.energy_kWh,expected,'AbsTol',1e-12);
end
function testFuelModeHotelLoad(t)
[c,o]=inputs(); p=HybridPowertrain(c);
a=p.step(100,get_state(0),'fuel',1,.1,o.prop);
verifyEqual(t,a.fuel_lb,6.5,'AbsTol',1e-12);
verifyEqual(t,a.energy_kWh,c.hotel_load_kW*.1,'AbsTol',1e-12);
verifyEqual(t,a.electric_shaft_kW,0);
end
function testCombinedShaftBalance(t)
[c,o]=inputs(); p=HybridPowertrain(c);
a=p.step(867,get_state(0),'hybrid',.25,.01,o.prop);
verifyEqual(t,a.turbine_hp+a.electric_shaft_kW/.745699872,867,'AbsTol',1e-10);
end
function testReserveStopsWithoutFallback(t)
[c,o]=inputs(); p=HybridPowertrain(c); E=p.energy_kWh;
verifyError(t,@() p.step(100,get_state(0),'electric',1,1,o.prop),'Hybrid:BatteryReserve');
verifyEqual(t,p.energy_kWh,E);
end
function testMotorLimit(t)
[c,o]=inputs(); p=HybridPowertrain(c);
verifyError(t,@() p.step(867,get_state(0),'electric',1,.01,o.prop),'Hybrid:MotorPower');
end
function testBatteryPowerLimit(t)
[c,o]=inputs(); c.battery_max_discharge_C=.1; p=HybridPowertrain(c);
verifyError(t,@() p.step(100,get_state(0),'electric',1,.01,o.prop),'Hybrid:BatteryPower');
end
function testTurbineLapseLimit(t)
[c,o]=inputs(); p=HybridPowertrain(c);
verifyError(t,@() p.step(867,get_state(8000),'fuel',0,.01,o.prop),'Hybrid:TurbinePower');
end
function testPropellerLimit(t)
[c,o]=inputs(); p=HybridPowertrain(c);
verifyError(t,@() p.step(900,get_state(0),'hybrid',.25,.01,o.prop),'Hybrid:PropellerPower');
end
function testFuelFailureTransactional(t)
[c,o]=inputs(); p=HybridPowertrain(c); E=p.energy_kWh;
verifyError(t,@() p.step(100,get_state(0),'fuel',0,.1,o.prop,0),'Hybrid:FuelDepleted');
verifyEqual(t,p.energy_kWh,E);
end
function testMissionConservation(t)
r=hybrid_mission(); verifyTrue(t,r.feasible); verifyEqual(t,r.completed_segments,10);
verifyEqual(t,r.mass_balance_error_lb,0,'AbsTol',1e-8);
verifyEqual(t,sum([r.segments.battery_kWh]),r.battery_used_kWh,'AbsTol',1e-9);
verifyGreaterThanOrEqual(t,r.final_soc,.2);
rows=r.segments([r.segments.mode]=="electric");
verifyEqual(t,[rows.fuel_lb],zeros(size(rows)));
verifyEqual(t,[rows.weight_fraction],ones(size(rows)));
end
function testSourceComparison(t)
r=compare_hybrid_modes(); verifyTrue(t,r.both_feasible);
verifyEqual(t,r.hybrid.initial_weight_lb,r.fuel_only.initial_weight_lb);
verifyGreaterThan(t,r.fuel_saved_lb,0);
end
function testInvalidMode(t)
[c,o]=inputs(); p=HybridPowertrain(c);
verifyError(t,@() p.step(10,get_state(0),'auto',0,.1,o.prop),'Hybrid:Mode');
end
function testRefinement(t)
root=fileparts(fileparts(mfilename('fullpath')));
J=jsondecode(fileread(fullfile(root,'config','Hybrid_requirements.json'))); J.hybrid.time_step_s=2.5;
f=[tempname '.json']; cleanup=onCleanup(@() delete(f));
fid=fopen(f,'w'); fwrite(fid,jsonencode(J)); fclose(fid);
a=hybrid_mission(); b=hybrid_mission(f); verifyTrue(t,b.feasible);
verifyEqual(t,a.fuel_used_lb,b.fuel_used_lb,'AbsTol',.1);
verifyEqual(t,a.battery_used_kWh,b.battery_used_kWh,'AbsTol',.01);
end
function testOverweightAndModeFailure(t)
root=fileparts(fileparts(mfilename('fullpath')));
J=jsondecode(fileread(fullfile(root,'config','Hybrid_requirements.json')));
f=[tempname '.json']; cleanup=onCleanup(@() delete(f));
J.hybrid.payload_lb=5000; write_json(f,J); r=hybrid_mission(f);
verifyFalse(t,r.feasible); verifyTrue(t,startsWith(r.failure,"Hybrid:MTOW"));
J.hybrid.payload_lb=800; J.segments=json_as_struct_array(J.segments);
J.segments(2).mode='electric'; write_json(f,J); r=hybrid_mission(f);
verifyFalse(t,r.feasible); verifyTrue(t,startsWith(r.failure,"Hybrid:MotorPower"));
verifyEqual(t,r.completed_segments,1);
end
function write_json(f,J)
fid=fopen(f,'w'); fwrite(fid,jsonencode(J)); fclose(fid);
end
