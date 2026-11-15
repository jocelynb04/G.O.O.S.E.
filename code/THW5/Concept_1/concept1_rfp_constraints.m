function cons = concept1_rfp_constraints()
%CONCEPT1_RFP_CONSTRAINTS  Constraint conditions from the Tidal Flight RFP.
%
%   cons = concept1_rfp_constraints() returns a struct array in the format
%   get_con expects (name, type, altitude_ft, distance_ft, G, ktas,
%   power_index, config, beta, power_setting, oei, propeller_stopped,
%   max_continuous) plus two extra fields that only the Concept 1
%   constraint functions read:
%
%       roc_fpm   required rate of climb [ft/min]       (climb conditions)
%       mu        resistance / deceleration coefficient  (takeoff, landing)
%
%   RFP requirement                                   -> condition
%   ------------------------------------------------------------------
%   180 KTAS at 10,000 ft density altitude, MTOW      -> 1 cruise_speed
%   best ROC >= 500 ft/min at 10,000 ft DA, MTOW      -> 2 climb_rate
%   ROC 2000 ft/min, MSL ISA, MTOW                    -> 3 climb_rate
%   OEI ROC 450 ft/min, MSL ISA, MTOW                 -> 4 climb_rate (oei)
%   takeoff over 50 ft in 2000 ft, calm water, MTOW   -> 5 water_takeoff
%   landing over 50 ft in 2000 ft, calm water, MTOW   -> 6 water_landing
%   landing over 50 ft in 2000 ft, land, MTOW         -> 7 land_landing
%
%   ASSUMPTIONS TO REVIEW (each is one number in this file):
%     - Cruise and AEO climb use maximum continuous turboprop power. The RFP
%       gives no power setting; max continuous is the permissive reading.
%     - OEI climb uses takeoff-rated turboprop power on the remaining
%       engine, takeoff flaps, gear up, stopped propeller.
%     - Takeoff is electric only (RFP: no tailpipe emissions in takeoff,
%       landing and on-water operations).
%     - mu = 0.10 (water takeoff resistance), 0.15 (water landing
%       deceleration), 0.35 (land braking) are PLACEHOLDERS. The RFP asks
%       for a towing-tank campaign; replace these with that data. The
%       landing wall in particular is very sensitive to the water value.
%     - beta = 1 everywhere: the RFP states every condition at MTOW.
%
%   NOT INCLUDED: the 20 KTAS crosswind landing and the wingspan limit of
%   65 ft. The span limit depends on W_TO, which the W/S - W/P envelope
%   does not see; check it after sizing (b = sqrt(AR * S_ref)).

    cons = [ ...
        make_con("Cruise 180 KTAS at 10,000 ft DA", "cruise_speed", ...
                 10000, [], 180, [], "clean", 1.0, 1.0, false, false, true, 0), ...
        make_con("Best ROC 500 ft/min at 10,000 ft DA", "climb_rate", ...
                 10000, 500, [], [], "clean", 1.0, 1.0, false, false, true, 0), ...
        make_con("ROC 2000 ft/min at MSL", "climb_rate", ...
                 0, 2000, [], [], "clean", 1.0, 1.0, false, false, true, 0), ...
        make_con("OEI ROC 450 ft/min at MSL", "climb_rate", ...
                 0, 450, [], [], "takeoff_flaps_gear_up", 1.0, 1.0, true, true, false, 0), ...
        make_con("Water takeoff, 50 ft obstacle in 2000 ft", "water_takeoff", ...
                 0, [], [], 2000, "takeoff_flaps_gear_up", 1.0, 1.0, false, false, false, 0.10), ...
        make_con("Water landing, 50 ft obstacle in 2000 ft", "water_landing", ...
                 0, [], [], 2000, "landing_flaps_gear_up", 1.0, 1.0, false, false, false, 0.15), ...
        make_con("Land landing, 50 ft obstacle in 2000 ft", "land_landing", ...
                 0, [], [], 2000, "landing_flaps_gear_down", 1.0, 1.0, false, false, false, 0.35) ...
    ];
end


function c = make_con(name, type, alt_ft, roc_fpm, ktas, dist_ft, config, ...
        beta, power_setting, oei, prop_stopped, max_cont, mu)
%MAKE_CON  One condition with every field present, so the array concatenates.
    c.name              = name;
    c.type              = type;
    c.altitude_ft       = alt_ft;
    c.distance_ft       = dist_ft;
    c.G                 = [];
    c.ktas              = ktas;
    c.power_index       = [];
    c.config            = config;
    c.beta              = beta;
    c.power_setting     = power_setting;
    c.oei               = oei;
    c.propeller_stopped = prop_stopped;
    c.max_continuous    = max_cont;
    c.roc_fpm           = roc_fpm;
    c.mu                = mu;
end
