function p = grand_caravan_ex_params()
%GRAND_CARAVAN_EX_PARAMS  Published C208B EX Amphibian benchmarks.
% Source: https://cessna.txtav.com/en/turboprop/grand-caravan-ex
% All fields ending _assumed are PROVISIONAL engineering estimates.
% Does not represent a validated model, POH or AFM.
    p.aircraft = 'Cessna Grand Caravan EX Amphibian (C208B)';
    p.engine = 'PT6A-140';
    p.n_engines = 1;
    p.P_SL_shp = 867;
    p.MTOW_lb = 9062;
    p.ramp_max_lb = 9097;
    p.BEW_lb = 5975;
    p.landplane_BEW_lb = 5310;
    p.float_installation_net_Bew_delta_lb = p.BEW_lb - p.landplane_BEW_lb;
    p.S_ref_ft2 = 279;
    p.span_ft = 52 + 1/12;
    p.AR = p.span_ft^2/p.S_ref_ft2;
    p.length_ft = 41 + 7/12;
    p.height_ft = 17 + 5/12;
    p.cabin_width_ft = 64/12;
    p.cabin_height_ft = 54/12;
    p.cabin_length_ft = 16 + 9/12;
    p.max_cruise_ktas = 164;
    p.max_range_nm = 813;
    p.usable_fuel_lb = 2246;
    p.usable_fuel_gal = 335;
    p.max_climb_fpm = 1212;
    p.stall_kcas = 59;
    p.water_takeoff_distance_ft = 3271;
    p.water_run_ft = 2000;
    p.water_landing_distance_ft = 2004;
    p.max_operating_alt_ft = 20000;
    % Engine family length range 61.5-64in per Pratt & Whitney PT6A specs;
    % 63in is chosen as a family-level midpoint, not verified for -140.
    p.engine_dry_weight_lb_assumed = 425;
    p.engine_length_ft_assumed = 63/12;
    p.BSFC_lb_per_shp_hr_assumed = 0.65;
    p.power_lapse_sigma_exponent_assumed = 0.65;
    p.eta_p_cruise_assumed = 0.80;
    p.eta_p_climb_assumed = 0.75;
    p.eta_p_loiter_assumed = 0.72;
    p.engine_weight_scaling_exp_assumed = 0.80;
    p.engine_length_scaling_exp_assumed = 0.40;
    p.wing_taper_ratio_assumed = 0.615;
    p.Cfe_assumed = 0.0055;
    p.CD0_float_increment_assumed = 0.012;
end
