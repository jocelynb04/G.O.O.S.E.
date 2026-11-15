function [fuel_burned, segment_weight, segment_wf, detail, ...
          battery_energy_total_kWh, battery_energy_by_segment_kWh] = ...
          concept1_run_mission_L2(W_TO, obj)
%CONCEPT1_RUN_MISSION_L2  Concept 1 mission with fuel and battery accounting.
%
%   Adapted from the professor's run_mission_L2.m. Climb, cruise, and
%   loiter use the Concept 1 segment models; descent retains the professor's
%   Roskam fraction. Electric takeoff, landing, taxi, and water-operation
%   segments consume battery energy and no fuel.
%
%   Electric-segment requirements:
%     - Each electric segment must provide time_min in the mission profile.
%     - Optional power_fraction is the fraction of rated electric shaft
%       power used during that segment. If omitted, 1.0 is used as a
%       conservative screening assumption.
%     - Water-operation energy is only a shaft-power estimate. This model
%       does not account for hydrodynamic resistance or water spray.
%
%   The battery remains aboard throughout the mission. Electric energy
%   draw therefore does not change segment_weight; it contributes to the
%   separately sized battery. This function does not add a reserve margin.
%
%   Outputs
%     fuel_burned                   fuel burned per segment [lbf]
%     segment_weight                weight at segment boundaries [lbf]
%     segment_wf                    weight fraction per segment [-]
%     detail                        per-segment performance and energy
%     battery_energy_total_kWh      total mission battery draw [kWh]
%     battery_energy_by_segment_kWh battery draw per segment [kWh]

    n = numel(obj.miss.segments);

    fuel_burned = zeros(1, n);
    segment_wf = ones(1, n);
    segment_weight = zeros(1, n + 1);
    segment_weight(1) = W_TO;
    battery_energy_by_segment_kWh = zeros(1, n);
    battery_energy_total_kWh = 0;

    blank = struct('type', "", 'CL', NaN, 'LD', NaN, 'V_fps', NaN, ...
        'time_hr', NaN, 'n_sub', NaN, 'propulsion_mode', "", ...
        'battery_energy_kWh', 0);
    detail = repmat(blank, 1, n);

    W = W_TO;
    for k = 1:n
        seg = get_miss_seg(k, obj.miss);
        raw_seg = obj.miss.segments(k);
        seg_type = lower(string(seg.type));
        info = blank;
        info.type = seg_type;

        switch seg_type
            case {"takeoff", "landing", "taxi", "water_takeoff", ...
                    "water_landing", "water_taxi"}
                % These operations are electric-only for Concept 1.
                if isempty(seg.time_min) || ~isscalar(seg.time_min) || ...
                        ~isfinite(seg.time_min) || seg.time_min <= 0
                    error('concept1_run_mission_L2:MissingElectricDuration', ...
                        ['Electric mission segment %d (%s) must specify ', ...
                         'a positive time_min in the mission profile.'], ...
                        k, seg_type);
                end

                power_fraction = 1.0;
                if isfield(raw_seg, 'power_fraction') && ...
                        ~isempty(raw_seg.power_fraction)
                    power_fraction = raw_seg.power_fraction;
                end
                if ~isscalar(power_fraction) || ~isfinite(power_fraction) || ...
                        power_fraction < 0 || power_fraction > 1
                    error('concept1_run_mission_L2:InvalidPowerFraction', ...
                        'Segment %d power_fraction must be between 0 and 1.', k);
                end

                h_electric = seg.alt;
                if isempty(h_electric)
                    h_electric = 0; % ground operations default to sea level
                end
                state = get_state(h_electric);
                seg.propulsion_mode = "electric";
                P_shaft = obj.prop.available_power(state, seg) * power_fraction;
                E_kWh = obj.prop.battery_energy_kWh(P_shaft, seg.time_min / 60);
                battery_energy_by_segment_kWh(k) = E_kWh;
                battery_energy_total_kWh = battery_energy_total_kWh + E_kWh;

                % Battery is not consumed as mass during operation.
                fuel_burned(k) = 0;
                segment_wf(k) = 1;
                W_next = W;
                info.time_hr = seg.time_min / 60;
                info.n_sub = 1;
                info.propulsion_mode = "electric";
                info.battery_energy_kWh = E_kWh;

            case "climb"
                [W_next, fuel_burned(k), segment_wf(k), info] = ...
                    concept1_climb(W, obj, k);
                info = add_energy_fields_(info, "turboprop", 0);

            case "cruise"
                [W_next, fuel_burned(k), segment_wf(k), info] = ...
                    concept1_cruise_lift(W, obj, k);
                info = add_energy_fields_(info, "turboprop", 0);

            case "loiter"
                [W_next, fuel_burned(k), segment_wf(k), info] = ...
                    concept1_loiter_lift(W, obj, k);
                info = add_energy_fields_(info, "turboprop", 0);

            case "descent"
                [W_next, fuel_burned(k)] = fixed_fraction_(W, 0.992);
                segment_wf(k) = W_next / W;
                info.propulsion_mode = "turboprop";

            otherwise
                error('concept1_run_mission_L2:UndefinedSegment', ...
                    'Mission segment type "%s" is not defined.', seg_type);
        end

        segment_weight(k + 1) = W_next;
        W = W_next;
        detail(k) = info;
    end
end


function [W_out, fuel_used] = fixed_fraction_(W_in, WF)
%FIXED_FRACTION_  Apply the professor's fixed descent weight fraction.
    fuel_used = (1 - WF) * W_in;
    W_out = W_in * WF;
end


function info = add_energy_fields_(info, mode, E_kWh)
%ADD_ENERGY_FIELDS_  Keep detail structs uniform across mission segments.
    info.propulsion_mode = string(mode);
    info.battery_energy_kWh = E_kWh;
end
