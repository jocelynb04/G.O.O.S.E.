function result = run_concept4_sizing(requirements_filename,assumptions_filename,output_dir)
here = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(requirements_filename)
    requirements_filename = fullfile(here,'concept4_aero_hydro_requirements.json');
end
if nargin < 2 || isempty(assumptions_filename)
    assumptions_filename = fullfile(here,'concept4_integration_assumptions.json');
end
if nargin < 3 || isempty(output_dir)
    output_dir = fullfile(here,'results');
end
J = jsondecode(fileread(requirements_filename));
assumptions = jsondecode(fileread(assumptions_filename));
solver = Concept4Sizing(J,assumptions);
result = sizing_mainloop(solver);
if ~isfolder(output_dir), mkdir(output_dir); end
write_json_C4(fullfile(output_dir,'sizing_results.json'),result);
if ~isempty(result.history)
    hist = result.history;
    N = numel(hist);
    iteration = zeros(N,1);
    W_TO_lb = zeros(N,1);
    S_ref_ft2 = zeros(N,1);
    motor_shaft_hp = zeros(N,1);
    generator_engine_hp_each = zeros(N,1);
    battery_capacity_kwh = zeros(N,1);
    OEW_lb = zeros(N,1);
    payload_lb = zeros(N,1);
    mission_fuel_lb = zeros(N,1);
    mission_soc_end = zeros(N,1);
    span_ft = zeros(N,1);
    max_residual = zeros(N,1);
    for i = 1:N
        row = hist(i);
        iteration(i) = row.iteration;
        W_TO_lb(i) = row.proposed.W_TO_lb;
        S_ref_ft2(i) = row.proposed.S_ref_ft2;
        motor_shaft_hp(i) = row.proposed.motor_shaft_hp;
        generator_engine_hp_each(i) = row.proposed.generator_engine_hp_each;
        battery_capacity_kwh(i) = row.proposed.battery_capacity_kwh;
        OEW_lb(i) = row.OEW_lb;
        payload_lb(i) = row.payload_lb;
        mission_fuel_lb(i) = row.mission_fuel_lb;
        mission_soc_end(i) = row.mission_soc_end;
        span_ft(i) = row.span_ft;
        max_residual(i) = row.max_residual;
    end
    T = table(iteration,W_TO_lb,S_ref_ft2,motor_shaft_hp,generator_engine_hp_each, ...
        battery_capacity_kwh,OEW_lb,payload_lb,mission_fuel_lb,mission_soc_end, ...
        span_ft,max_residual);
    writetable(T,fullfile(output_dir,'sizing_history.csv'));
end
if ~isempty(result.final) && ~isempty(result.final.mission.segments)
    seg = result.final.mission.segments;
    writetable(struct2table(seg),fullfile(output_dir,'mission_segments.csv'));
end
try
    report = Concept4Verification(J,result,solver);
catch ME
    report = struct('summary_status','VERIFICATION_ERROR', 'error',ME.message);
end
write_json_C4(fullfile(output_dir,'RFP_status.json'),report);
try
    envelope = matching_envelope_C4(J,solver.geom,solver.aero,solver.prop, ...
        result.state.W_TO_lb,assumptions);
    if ~isempty(envelope.candidates)
        writetable(struct2table(envelope.candidates), ...
            fullfile(output_dir,'matching_diagram_data.csv'));
    end
catch ME
    fprintf('Matching sweep failed: %s\n',ME.message);
end
fprintf('STATUS: %s\n',result.status);
fprintf('ITERATIONS: %d\n',result.iterations_completed);
disp(result.state);
if ~isempty(result.final)
    fprintf('MASS RESIDUAL [lb]: %.6f\n',result.final.mass_closure_residual_lb);
end
if ~isempty(result.failure_reason)
    fprintf('STOP REASON: %s\n',result.failure_reason);
end
fprintf('RESULTS: %s\n',output_dir);
end
