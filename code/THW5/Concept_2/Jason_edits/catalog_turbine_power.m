function [P_each, info] = catalog_turbine_power(engine, state, rating)
%CATALOG_TURBINE_POWER  Shaft hp of ONE reference turbine from public charts.
%   state.alt is pressure altitude [ft]. Optional state.oat_C overrides ISA
%   for a hot/cold-day POWER sensitivity; it does not change aircraft aero.
%   Without oat_C, use the project's ISA atmosphere (Aerospace Toolbox).
%
%   Source curves exist at sea level and 10000 ft only. Interpolation at
%   intermediate altitudes is assumed linear at fixed ISA temperature offset.
%   This follows each altitude's local ISA temperature, rather than using
%   a sea-level temperature on the 10000-ft curve during an ISA climb.
%   The curves are
%   rounded manual readings of a brochure, not a manufacturer engine deck.
%   Continuous power uses the same thermal ceiling, capped by its rating:
%   that is an explicit assumption until a separate continuous map exists.
%   This returns reference turbine output, before custom accessory/gearbox
%   loads; it includes no electric motor, OEI, restart or idle-flow model.
    validateattributes(state.alt, {'numeric'}, ...
        {'real', 'scalar', 'finite', '>=', 0, '<=', 10000});
    if isfield(state, 'oat_C') && ~isempty(state.oat_C)
        oat_C = state.oat_C;
    else
        atmosphere = AircraftState(state.alt, 0);
        oat_C = atmosphere.T_atm / 1.8 - 273.15;
    end
    validateattributes(oat_C, {'numeric'}, {'real', 'scalar', 'finite'});
    switch string(rating)
        case "takeoff"
            limit = engine.takeoff_hp_each;
        case "max_continuous"
            limit = engine.continuous_hp_each;
        otherwise
            error('TtpaProp:UndefinedRating', ...
                'Unsupported turbine rating: %s.', string(rating));
    end

    if state.alt == 0
        ceiling = chart_value(engine.sea_level_curve, oat_C);
    elseif state.alt == 10000
        ceiling = chart_value(engine.altitude_10000_curve, oat_C);
    else
        local_atmosphere = AircraftState(state.alt, 0);
        upper_atmosphere = AircraftState(10000, 0);
        delta_ISA_C = oat_C - (local_atmosphere.T_atm / 1.8 - 273.15);
        % Interpolate along the same ISA+offset day at both source altitudes.
        % This is still a study interpolation, not a supplied engine deck.
        P0 = chart_value(engine.sea_level_curve, 15 + delta_ISA_C);
        upper_oat_C = upper_atmosphere.T_atm / 1.8 - 273.15 + delta_ISA_C;
        P10 = chart_value(engine.altitude_10000_curve, upper_oat_C);
        ceiling = P0 + (P10 - P0) * state.alt / 10000;
    end
    P_each = min(limit, ceiling);
    info = struct('engine', string(engine.name), 'oat_C', oat_C, ...
        'altitude_ft', state.alt, 'rating', string(rating), ...
        'basis', string(engine.power_basis));
end

function P = chart_value(curve, temperature)
    P = interp1(curve.oat_C, curve.shaft_hp_each, temperature, 'linear', NaN);
    if ~isfinite(P)
        error('TtpaProp:OutsideTurbineMap', ...
            'OAT %.1f C is outside the required published curve range.', temperature);
    end
end
