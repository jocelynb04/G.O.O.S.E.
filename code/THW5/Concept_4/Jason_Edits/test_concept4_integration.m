function results=test_concept4_integration()
root=fileparts(mfilename('fullpath'));addpath(root,'-begin');
results=runtests({'Concept4OpenVSPTest.m','SeaplanePropBatteryTest.m','Concept4MissionRouteTest.m'});
assert(all([results.Passed]),'C4:Tests','At least one test did not pass.');
end
