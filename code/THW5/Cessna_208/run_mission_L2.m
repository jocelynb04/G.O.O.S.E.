
function [fuel_burned, segment_weight, segment_wf, detail] = run_mission_L2(W_TO, obj)
% Level-2 mission: combines fixed-fraction segments with Level-2
% climb, cruise, and loiter calculations.

    n = numel(obj.miss.segments);

    fuel_burned    = zeros(1, n);
    segment_wf     = zeros(1, n);
    segment_weight = zeros(1, n + 1);
    segment_weight(1) = W_TO;

    blank = struct('type', "", 'CL', NaN, 'LD', NaN, ...
                   'V_fps', NaN, 'time_hr', NaN, 'n_sub', NaN);

    detail = repmat(blank, 1, n);

    W = W_TO;

    for k = 1:n

        seg = get_miss_seg(k, obj.miss);
        info = blank;
        info.type = lower(string(seg.type));

        switch info.type

            case "takeoff"
                [W, fuel_burned(k), segment_wf(k)] = ...
                    fixed_fraction_(W, 0.984);

            case "climb"
                [W, fuel_burned(k), segment_wf(k), info] = ...
                    segment_climb_L2(W, obj, k);

            case "cruise"
                [W, fuel_burned(k), segment_wf(k), info] = ...
                    segment_cruise_L2(W, obj, k);

            case "descent"
                [W, fuel_burned(k), segment_wf(k)] = ...
                    fixed_fraction_(W, 0.992);

            case "loiter"
                [W, fuel_burned(k), segment_wf(k), info] = ...
                    segment_loiter_L2(W, obj, k);

            case "landing"
                [W, fuel_burned(k), segment_wf(k)] = ...
                    fixed_fraction_(W, 0.992);

            otherwise
                error('run_mission_L2:UndefinedSegment', ...
                    'Mission segment type "%s" is not defined.', ...
                    info.type);

        end

        segment_weight(k + 1) = W;
        detail(k) = info;

    end

end


function [W_out, fuel_used, WF] = fixed_fraction_(W_in, WF)
% A segment flown at a fixed Roskam weight fraction.

    fuel_used = (1 - WF) * W_in;
    W_out = W_in * WF;

end
