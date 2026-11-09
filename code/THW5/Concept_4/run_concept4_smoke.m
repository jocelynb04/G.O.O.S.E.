function out = run_concept4_smoke()
here = fileparts(mfilename('fullpath'));
J = jsondecode(fileread(fullfile(here,'concept4_aero_hydro_requirements.json')));
A = jsondecode(fileread(fullfile(here,'concept4_integration_assumptions.json')));
p = SeaplaneProp_Concept4(J);
g = SeaplaneGeom(J,p);
g.S_ref = J.initial_example_only.wing_area_ft2;
a = SeaplaneAero_Concept4(J,g);
h = SeaplaneHydro_Concept4(J,g,a);
w = SeaplaneWeights(J,g,p);
drag = a.drag_breakdown(struct('alt_ft',10000,'ktas',180));
buoyancy = h.buoyancy_screen(J.initial_example_only.takeoff_weight_lb);
try
    mission = Concept4Mission(J,g,a,p,A);
    mission_probe = mission.run(J.initial_example_only.takeoff_weight_lb,'std_mission',true);
catch ME
    mission_probe = struct('status','INFEASIBLE','reason',ME.message);
end
out = struct('wingspan_ft',g.b,'S_ref_ft2',g.S_ref, ...
    'CD0_clean',drag.CD0_total,'OEW_lb',w.OEW(J.initial_example_only.takeoff_weight_lb), ...
    'payload_lb',w.payload(),'buoyancy',buoyancy,'mission_probe',mission_probe);
disp(out);
end
