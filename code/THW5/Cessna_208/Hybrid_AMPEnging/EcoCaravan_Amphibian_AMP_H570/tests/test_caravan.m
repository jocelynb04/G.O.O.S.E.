function tests = test_caravan
tests = functiontests(localfunctions);
end
function testAtmosphere(t)
s=get_state(0); verifyEqual(t,s.sigma,1); verifyEqual(t,s.rho,0.0023769,'RelTol',1e-4);
s=get_state(10000); verifyEqual(t,s.sigma,0.73848,'RelTol',1e-4);
verifyError(t,@() get_state(40000),'AircraftState:AltitudeRange');
end
function testBundleAndAnchor(t)
o=ttpa_disciplines(); verifyClass(t,o.prop,'TtpaProp');
verifyEqual(t,o.wts.OEW(9062),5975,'AbsTol',0.02);
b=o.geom.b; o.geom.S_ref=300; verifyGreaterThan(t,o.geom.b,b);
verifyEqual(t,o.aero.CD0,o.aero.Cfe*o.geom.S_wet_over_S_ref+0.012,'AbsTol',1e-12);
end
function testMissionBalance(t)
o=ttpa_disciplines(); [f,frac,b,w,wf]=mission_fuel(9062,o);
verifyGreaterThan(t,f,0); verifyLessThan(t,f,9062);
verifyEqual(t,sum(b),w(1)-w(end),'AbsTol',1e-8);
verifyEqual(t,prod(wf),w(end)/w(1),'AbsTol',1e-12);
verifyEqual(t,frac,f/9062);
end
function testCruisePhysics(t)
o=ttpa_disciplines(); [wp,e]=constraint_cruise_speed([25 35],o,6);
verifyEqual(t,wp,550*e.eta_p*e.kP./(e.V_fps*(e.CD./e.CL)),'RelTol',1e-12);
end
function testClosure(t)
[w,d]=SizingSteps.togw_update(800,5000,1200,8000);
verifyEqual(t,d,0.225,'AbsTol',1e-12); verifyEqual(t,w,800/d);
[w,~]=SizingSteps.togw_update(800,8000,1200,8000); verifyTrue(t,isnan(w));
end
function testSizing(t)
o=ttpa_disciplines(); opts=grand_caravan_ex_initial_opts(o);
[h,c,s]=sizing_mainloop(o,opts); verifyTrue(t,c);
verifyLessThan(t,max([h(end).res_W h(end).res_P h(end).res_S]),opts.tol);
verifyEqual(t,o.wts.W_TO,s.W0); verifyEqual(t,o.prop.P_SL,s.P0);
end

function testInvalidInputs(t)
o=ttpa_disciplines(); o.miss.method="unsupported";
verifyError(t,@() mission_fuel(9062,o),'mission_fuel:UndefinedMethod');
J=jsondecode(fileread(ttpa_requirements_path())); J.missions.std_mission.climb_segments=0;
f=[tempname '.json']; c=onCleanup(@() delete(f));
fid=fopen(f,'w'); fwrite(fid,jsonencode(J)); fclose(fid);
verifyError(t,@() ttpa_disciplines(f),'MATLAB:expectedPositive');
end
function testFailurePaths(t)
o=ttpa_disciplines(); o.prop.P_SL=1;
verifyError(t,@() segment_climb_L2(9062,o,2),'segment_climb_L2:CannotClimb');
end

