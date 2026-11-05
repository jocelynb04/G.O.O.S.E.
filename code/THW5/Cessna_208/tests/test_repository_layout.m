function tests=test_repository_layout
tests=functiontests(localfunctions);
end
function testCurrentFolderIndependent(t)
root=setup_project(); original=pwd; cleanup=onCleanup(@() cd(original)); cd(tempdir);
a=run_profile(); b=run_caravan();
verifyEqual(t,a.fuel_lb,b.fuel_lb,'AbsTol',1e-8);
verifyEqual(t,ttpa_requirements_path(),fullfile(root,'config','GrandCaravanEX_requirements_IHW3.json'));
verifyTrue(t,isfile(ttpa_requirements_path()));
end
function testThreeDegreeInputPreserved(t)
J=jsondecode(fileread(ttpa_requirements_path()));
conditions=json_as_struct_array(J.constraints.conditions);
verifyEqual(t,conditions(3).G,0.0524078,'AbsTol',1e-12);
end
