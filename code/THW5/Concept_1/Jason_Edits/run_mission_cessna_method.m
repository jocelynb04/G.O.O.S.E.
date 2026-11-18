function report = run_mission_cessna_method(frameworkDir)
% Run the current imported geometry, mission and constraint report.
arguments
    frameworkDir (1,1) string = ""
end
setup_jason_edits(frameworkDir);
report = run_concept1_openvsp();
end
