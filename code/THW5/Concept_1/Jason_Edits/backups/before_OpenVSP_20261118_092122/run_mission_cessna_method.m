function report = run_mission_cessna_method(frameworkDir)
%RUN_MISSION_CESSNA_METHOD Run Concept 1 with modeled electric final approach.
%   The optional frameworkDir argument points to IHW3/student_starter.
arguments
    frameworkDir (1,1) string = ""
end
here = fileparts(mfilename('fullpath'));
setup_jason_edits(frameworkDir);

obj = concept1_disciplines();
approach = obj.miss.electric_final_approach;
W_TO = 9000;
wingLoading = 12.50;
obj.geom.S_ref = W_TO / 20;
obj.prop.P_SL = W_TO / 9;
powerLoading = 0.95 * concept1_matching_envelope(wingLoading, obj);
obj.geom.S_ref = W_TO / wingLoading;
obj.prop.P_SL = W_TO / powerLoading;

types = string({obj.miss.segments.type});
landingIndex = find(types == "water_landing");
obj.miss.segments(landingIndex - 1).alt_ft = approach.start_alt_ft;
[fuel, weight, fraction, detail, groundEnergy, battery] = concept1_run_mission_L2(W_TO, obj);

% Apply the Cessna time-stepped drag and flight-path power equation using
% Concept 1 geometry, approach weight, polar, and landing efficiency.
speed = approach.ktas * 6076.11549 / 3600;
verticalSpeed = speed * sind(approach.flight_path_angle_deg);
duration = (approach.end_alt_ft - approach.start_alt_ft) / verticalSpeed;
stepCount = ceil(duration / approach.time_step_s);
dt = duration / stepCount;
approachWeight = weight(landingIndex);
condition = struct('config', approach.config, 'propeller_stopped', false);
shaftPower = zeros(1, stepCount);
stallMargin = zeros(1, stepCount);
for step = 1:stepCount
    altitude = approach.start_alt_ft + verticalSpeed * (step - 0.5) * dt;
    state = get_state(altitude);
    polar = obj.aero.get_config_polar(state, condition);
    qS = 0.5 * state.rho * speed^2 * obj.geom.S_ref;
    liftCoefficient = approachWeight * cosd(approach.flight_path_angle_deg) / qS;
    stallMargin(step) = polar.CLmax - obj.aero.CL_stall_margin - liftCoefficient;
    drag = qS * (polar.CD0 + polar.K1 * liftCoefficient^2);
    shaftPower(step) = max(0, (drag * speed + approachWeight * verticalSpeed) / ...
        (550 * obj.prop.eta_p_landing));
end
assert(all(stallMargin >= 0), 'The approach violates the configured stall margin.');
assert(max(shaftPower) <= obj.prop.P_electric_SL, 'Approach exceeds electric shaft power.');
approachEnergy = obj.prop.battery_energy_kWh(sum(shaftPower), dt / 3600);
totalEnergy = groundEnergy + approachEnergy;

columns = {'Type','Propulsion','Fuel_lbf','Battery_kWh','StartWeight_lbf', ...
    'EndWeight_lbf','WeightFraction','Duration_min'};
report = table(string({detail.type})', string({detail.propulsion_mode})', ...
    fuel(:), battery(:), weight(1:end-1)', weight(2:end)', fraction(:), ...
    60 * [detail.time_hr]', 'VariableNames', columns);
approachRow = table("electric_final_approach", "electric", 0, approachEnergy, ...
    approachWeight, approachWeight, 1, duration / 60, 'VariableNames', columns);
report = [report(1:landingIndex-1,:); approachRow; report(landingIndex:end,:)];
report = addvars(report, (1:height(report))', 'Before', 1, 'NewVariableNames', 'Segment');
assert(abs(W_TO - weight(end) - sum(report.Fuel_lbf)) < 1e-7);
assert(abs(sum(report.Battery_kWh) - totalEnergy) < 1e-7);
disp(report);
fprintf('Total fuel: %.2f lbf\nTotal battery energy: %.2f kWh\nEnd weight: %.2f lbf\n', ...
    sum(fuel), totalEnergy, weight(end));
fprintf('Takeoff rated power: %.2f hp\nApproach: %.3f min, peak %.2f hp\n', ...
    obj.prop.P_electric_SL, duration/60, max(shaftPower));
writetable(report, fullfile(here, 'results', 'Concept1_mission_segments_Cessna_method.csv'));
end
