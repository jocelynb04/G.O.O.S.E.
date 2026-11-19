function results = calculate_seat_mile_cost(repo_root, jet_a_price, jet_a_density)
%CALCULATE_SEAT_MILE_COST Compare the saved THW5 cases on a fuel-only basis.
%   calculate_seat_mile_cost("C:/path/to/Git") uses $6/US gal and 6.8 lb/US gal.
%   Pass a second or third argument to change price or density.
%   Run with the G.O.O.S.E. clone available locally. No files are changed.

    arguments
        repo_root (1,1) string {mustBeFolder}
        jet_a_price (1,1) double {mustBeFinite, mustBeNonnegative} = 6.00
        jet_a_density (1,1) double {mustBeFinite, mustBePositive} = 6.8
    end

    thw5 = fullfile(repo_root, "code", "THW5");
    c1 = fullfile(thw5, "Concept_1", "Jason_Edits");
    req1 = jsondecode(fileread(fullfile(c1, "Concept1_requirements_template.json")));
    mission1 = readtable(fullfile(c1, "results", "OpenVSP_mission_summary.csv"));

    c2 = fullfile(thw5, "Concept_2", "Results", "Current");
    missions2 = readtable(fullfile(c2, "mission_cases.csv"), TextType="string");
    normal2 = missions2(missions2.name == "normal", :);
    reserve2 = missions2(missions2.name == "go_around_reserve", :);
    assert(height(normal2) == 1 && height(reserve2) == 1, ...
        "Expected one normal and one go-around reserve case for Concept 2.");

    meters_per_nm = 1852;
    meters_per_mile = 1609.344;
    miles_per_nm = meters_per_nm / meters_per_mile;
    comparison_miles = req1.aircraft_requirements.minimum_range_statute_mi;
    c3 = fullfile(thw5, "Concept_3", "Concept3_Debug_Copy");
    [fuel3, miles3, fuel3_comparison] = run_concept3( ...
        c3, miles_per_nm, comparison_miles);

    c4 = fullfile(thw5, "Concept_4");
    req4 = jsondecode(fileread(fullfile(c4, "concept4_aero_hydro_requirements.json")));
    candidate4 = jsondecode(fileread(fullfile(c4, "results", "fixedwing_325", "summary.json")));

    concept = [1; 2; 2; 3; 3; 4];
    mission = ["Design mission with reserve"; "Normal mission"; ...
        "Go-around and reserve"; "Configured mission"; ...
        "1000-mile distance sensitivity"; "325-ft^2 wing, balk and reserve"];
    fuel_lb = [mission1.MissionFuel_lbf; normal2.fuel_burn_lb; ...
        reserve2.fuel_burn_lb; fuel3; fuel3_comparison; candidate4.mission_fuel_lb];
    statute_miles = [comparison_miles; normal2.route_distance_nm * miles_per_nm; ...
        reserve2.route_distance_nm * miles_per_nm; miles3; ...
        comparison_miles; req4.design_range_nmi * miles_per_nm];
    % Apply the RFP passenger seat count even to the 800-lb Concept 3 trial.
    passenger_seats = repmat(req1.aircraft_requirements.passengers, size(concept));
    available_seat_miles = passenger_seats .* statute_miles;
    fuel_gal = fuel_lb / jet_a_density;
    fuel_cost_usd = fuel_gal * jet_a_price;
    fuel_cents_per_seat_mile = 100 * fuel_cost_usd ./ available_seat_miles;
    notes = ["Onboard recharge balances the modeled battery cycle"; ...
        "Saved sizing trial has an unclosed mass budget"; ...
        "Saved sizing trial has an unclosed mass budget"; ...
        "800-lb model payload, nine-seat denominator assumed"; ...
        "800-lb model payload, no explicit balked landing"; ...
        "Ends below starting battery charge, recharge cost excluded"];
    results = table(concept, mission, fuel_lb, statute_miles, passenger_seats, ...
        available_seat_miles, fuel_gal, fuel_cost_usd, fuel_cents_per_seat_mile, notes);
end

function [fuel, miles, comparison_fuel] = run_concept3(folder, miles_per_nm, comparison_miles)
    starting_folder = pwd;
    starting_path = path;
    restore_folder = onCleanup(@() cd(starting_folder));
    restore_path = onCleanup(@() path(starting_path));
    cd(folder);
    obj = ttpa_disciplines();
    weight_lb = obj.sizing.W_TO_guess_lbf;
    cruise = strcmp({obj.miss.segments.type}, "cruise");
    assert(nnz(cruise) == 1, "Expected one Concept 3 cruise segment.");
    miles = obj.miss.segments(cruise).distance_nm * miles_per_nm;
    fuel = mission_fuel(weight_lb, obj);
    obj.miss.segments(cruise).distance_nm = comparison_miles / miles_per_nm;
    comparison_fuel = mission_fuel(weight_lb, obj);
end
