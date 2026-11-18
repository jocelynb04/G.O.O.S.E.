function report = run_concept1()
%RUN_CONCEPT1 Run geometry checks, constraints, weights and hybrid mission.
verify_concept1_openvsp_geometry();
report = run_concept1_openvsp();
end
