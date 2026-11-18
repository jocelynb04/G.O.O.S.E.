function map = build_assumed_turbine_map(settings, scenario)
%BUILD_ASSUMED_TURBINE_MAP  Provisional ISA shaft-power fractions for sizing.
%   map = build_assumed_turbine_map(settings) uses settings.active_scenario.
%   map = build_assumed_turbine_map(settings, "earlier_decline") overrides
%   the case without editing the requirements. Assign the result to
%   prop.turbine_map when comparing cases on an existing propulsion object.
%
%   THIS IS AN ASSUMPTION, NOT A PT6A ENGINE MAP. At ISA altitudes up to h_c,
%   the turbine maintains its rating; above h_c, the fraction decreases:
%       f(h) = min(1, (sigma(h) / sigma(h_c))^n).
%   n = 1 assumes power proportional to density after the flat region.
%   h_c and n are sensitivity parameters, not manufacturer specifications.
%   Both ratings use the same curve initially, but each fraction multiplies
%   its OWN aircraft-total rating in TtpaProp.turbine_power_available.
%   This supplies maximum available power, not a mission throttle schedule.
%   Fuel consumption, hot-day derating, accessories, and installation losses
%   need separate assumptions. No motor power is included in this map.
%
%   Uses get_state so the atmosphere matches the rest of the aircraft model
%   (MATLAB Aerospace Toolbox required). Lookup interpolation is linear and
%   does not extrapolate beyond the sampled altitude range.
    arguments
        settings (1,1) struct
        scenario (1,1) string = ""
    end
    if scenario == ""
        scenario = string(settings.active_scenario);
    end
    if ~isfield(settings.scenarios, char(scenario))
        error('TtpaProp:UnknownTurbineScenario', ...
            'Unknown assumed turbine scenario: %s.', scenario);
    end
    h = settings.altitude_ft;
    h_c = settings.scenarios.(char(scenario)).flat_rating_altitude_ft;
    n = settings.decline_exponent;
    validateattributes(h, {'numeric'}, ...
        {'real', 'vector', 'finite', 'nonnegative'});
    validateattributes(h_c, {'numeric'}, {'real', 'scalar', 'finite', 'nonnegative'});
    validateattributes(n, {'numeric'}, {'real', 'scalar', 'finite', 'positive'});
    if numel(h) < 2 || any(diff(h(:)) <= 0) || h(1) ~= 0 || h_c > h(end)
        error('TtpaProp:InvalidAssumedTurbineMap', ...
            ['Sample altitudes must increase strictly from zero and cover ', ...
             'the assumed flat-rating altitude.']);
    end

    % Include the transition itself so linear interpolation cannot smooth
    % across the corner and reduce power prematurely below h_c.
    h = unique([h(:); h_c]);
    transition_state = get_state(h_c);
    fractions = zeros(size(h));
    for i = 1:numel(h)
        state = get_state(h(i));
        fractions(i) = min(1, (state.sigma / transition_state.sigma)^n);
    end
    map = struct('altitude_ft', h, ...
        'takeoff_fraction', fractions, 'continuous_fraction', fractions, ...
        'source', 'ASSUMED ISA flat-rating sensitivity model; no engine calibration', ...
        'scenario', scenario, 'flat_rating_altitude_ft', h_c, ...
        'decline_exponent', n);
end
