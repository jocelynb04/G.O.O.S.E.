function tests=test_amp_h570
tests=functiontests(localfunctions);
end
function [c,p]=inputs()
root=fileparts(fileparts(mfilename('fullpath'))); J=jsondecode(fileread(fullfile(root,'config','AMP_H570_requirements.json')));
c=J.hybrid; p=AMPH570Powertrain(c);
end
function testPublishedRatings(t)
[c,~]=inputs(); verifyEqual(t,c.combined_peak_hp,764); verifyEqual(t,c.combined_continuous_hp,543);
verifyEqual(t,c.combustion_bsfc_lb_per_hp_hr,.34);
end
function testReplacementMass(t)
[c,p]=inputs(); expected=950+30*2.20462262185+40*1000/250*2.20462262185-595;
verifyEqual(t,p.mass_lb,expected,'AbsTol',1e-9);
verifyEqual(t,p.battery_mass_lb,40*1000/250*2.20462262185,'AbsTol',1e-9);
verifyLessThan(t,c.powerplant_dry_mass_lb_assumed,1000);
end
function testPeakShaftSplit(t)
[c,p]=inputs(); a=p.step(764,get_state(0),'hybrid',221/764,120/3600,[],100);
verifyEqual(t,a.combustion_hp,543,'AbsTol',1e-10);
verifyEqual(t,a.electric_shaft_kW/.745699872,221,'AbsTol',1e-10);
verifyEqual(t,a.fuel_lb,.34*543*120/3600,'AbsTol',1e-10);
verifyLessThan(t,p.get_soc(),c.initial_soc);
end
function testNo867hp(t)
[~,p]=inputs(); verifyError(t,@() p.step(867,get_state(0),'hybrid',.25,.01,[]),'Hybrid:PropellerPower');
end
function testPeakTimeAndRollback(t)
[~,p]=inputs(); p.step(764,get_state(0),'hybrid',221/764,120/3600,[]); E=p.energy_kWh;
verifyError(t,@() p.step(764,get_state(0),'hybrid',221/764,1/3600,[]),'Hybrid:PeakDuration');
verifyEqual(t,p.energy_kWh,E); verifyEqual(t,p.peak_elapsed_s,120,'AbsTol',1e-9);
p.step(100,get_state(0),'fuel',0,1/3600,[]); verifyEqual(t,p.peak_elapsed_s,0);
end
function testNoBatteryExtraFuelMultiplier(t)
[~,p]=inputs(); a=p.step(300,get_state(0),'fuel',0,.1,[]);
verifyEqual(t,a.fuel_lb,.34*300*.1,'AbsTol',1e-12);
end
function testChargingEnergyAndFuel(t)
[c,~]=inputs(); c.initial_soc=.5; p=AMPH570Powertrain(c); E=p.energy_kWh;
a=p.step(300,get_state(8000),'charge',0,.1,[]);
verifyGreaterThan(t,p.energy_kWh,E); verifyLessThan(t,a.battery_kW,0);
verifyGreaterThan(t,a.combustion_hp,300);
verifyEqual(t,a.combustion_hp,300+a.generator_shaft_kW/.745699872,'AbsTol',1e-10);
verifyEqual(t,a.fuel_lb,.34*a.combustion_hp*.1,'AbsTol',1e-10);
eta=c.generator_efficiency*c.inverter_efficiency*c.gearbox_efficiency;
verifyEqual(t,-a.battery_kW,(a.generator_shaft_kW*eta-c.hotel_load_kW)*c.battery_charge_efficiency,'AbsTol',1e-10);
end
function testChargeSOCAndPowerLimits(t)
[c,~]=inputs(); c.initial_soc=.89; p=AMPH570Powertrain(c);
p.step(300,get_state(8000),'charge',0,1,[]);
verifyEqual(t,p.get_soc(),.9,'AbsTol',1e-12);
a=p.step(543,get_state(8000),'charge',0,.01,[]);
verifyEqual(t,a.generator_shaft_kW,0,'AbsTol',1e-12);
verifyEqual(t,a.battery_kW,c.hotel_load_kW,'AbsTol',1e-12);
end
function testElectricAndCoreLimits(t)
[~,p]=inputs(); a=p.step(150,get_state(0),'electric',0,.01,[]);
verifyEqual(t,a.fuel_lb,0); verifyEqual(t,a.combustion_hp,0);
verifyError(t,@() p.step(250,get_state(0),'electric',0,.01,[]),'Hybrid:MotorPower');
verifyError(t,@() p.step(600,get_state(0),'fuel',0,.001,[]),'Hybrid:CombustionPower');
end
function testAltitudeAssumption(t)
[~,p]=inputs(); verifyEqual(t,p.combustion_available_hp(get_state(8000)),543,'AbsTol',1e-12);
verifyLessThan(t,p.combustion_available_hp(get_state(15000)),543);
end
function testMissionBalanceAndCharging(t)
r=eco_mission(); verifyTrue(t,r.feasible); verifyEqual(t,r.completed_segments,10);
verifyEqual(t,r.mass_balance_error_lb,0,'AbsTol',1e-8);
verifyEqual(t,r.battery_energy_balance_error_kWh,0,'AbsTol',1e-8);
verifyGreaterThan(t,r.battery_recharged_kWh,0);
verifyGreaterThanOrEqual(t,r.final_soc,.2);
verifyEqual(t,r.hybrid_empty_lb,5975+r.added_system_mass_lb,'AbsTol',.02);
verifyLessThanOrEqual(t,max(r.trace.combustion_hp),543+1e-8);
end
function testRejectedOriginalDemands(t)
root=fileparts(fileparts(mfilename('fullpath')));
a=eco_mission(fullfile(root,'config','scenarios','AMP_H570_original_867hp_demand.json'));
verifyFalse(t,a.feasible); verifyTrue(t,startsWith(a.failure,"Hybrid:PropellerPower"));
b=eco_mission(fullfile(root,'config','scenarios','AMP_H570_85kt_approach.json'));
verifyFalse(t,b.feasible); verifyTrue(t,startsWith(b.failure,"Hybrid:MotorPower"));
end
function testFuelFailureRollback(t)
[~,p]=inputs(); E=p.energy_kWh;
verifyError(t,@() p.step(300,get_state(0),'charge',0,.1,[],0),'Hybrid:FuelDepleted');
verifyEqual(t,p.energy_kWh,E); verifyEqual(t,p.peak_elapsed_s,0);
end
function testRefinedMission(t)
root=fileparts(fileparts(mfilename('fullpath'))); J=jsondecode(fileread(fullfile(root,'config','AMP_H570_requirements.json')));
J.hybrid.time_step_s=2.5; f=[tempname '.json']; cleanup=onCleanup(@() delete(f));
fid=fopen(f,'w'); fwrite(fid,jsonencode(J)); fclose(fid);
a=eco_mission(); b=eco_mission(f); verifyTrue(t,b.feasible);
verifyEqual(t,a.fuel_used_lb,b.fuel_used_lb,'AbsTol',.1);
verifyEqual(t,a.battery_used_kWh,b.battery_used_kWh,'AbsTol',.01);
end

function testFuelFullFlapAlternative(t)
root=fileparts(fileparts(mfilename('fullpath')));
r=eco_mission(fullfile(root,'config','scenarios','AMP_H570_fuel_approach.json'));
verifyTrue(t,r.feasible); verifyGreaterThan(t,r.segments(9).fuel_lb,0);
end

function testAlignedInputsAndCruiseShortfall(t)
root=fileparts(fileparts(mfilename('fullpath'))); J=jsondecode(fileread(fullfile(root,'config','AMP_H570_requirements.json')));
s=json_as_struct_array(J.segments); i=find(string({s.type})=="cruise",1);
verifyEqual(t,[s(i-1).end_alt_ft s(i).alt_ft s(i+1).start_alt_ft],[10000 10000 10000]);
o=ttpa_disciplines(); verifyEqual(t,o.aero.CLmax_landing,2.2);
r=eco_mission(); c=eco_cruise_check(J,r.initial_weight_lb);
verifyEqual(t,c.Speed_KTAS,[150;164]); verifyTrue(t,c.Passes(1)); verifyFalse(t,c.Passes(2));
end
