function out = grand_caravan_ex_benchmark()
%GRAND_CARAVAN_EX_BENCHMARK  Pure published-data arithmetic, no framework.
    p = grand_caravan_ex_params();
    out.aircraft = p.aircraft;
    out.WS_lb_ft2 = p.MTOW_lb / p.S_ref_ft2;
    out.WP_lb_shp = p.MTOW_lb / p.P_SL_shp;
    out.aspect_ratio = p.AR;
    out.basic_empty_fraction = p.BEW_lb / p.MTOW_lb;
    out.full_fuel_payload_at_MTOW_lb = p.MTOW_lb - p.BEW_lb - p.usable_fuel_lb;
    out.net_amphibian_empty_weight_delta_lb = p.float_installation_net_Bew_delta_lb;
    out.reference_wing_area_ft2 = p.S_ref_ft2;
    out.reference_MTOW_lb = p.MTOW_lb;
    out.reference_power_shp = p.P_SL_shp;
    out.reference_empty_weight_lb = p.BEW_lb;
    fprintf('Grand Caravan EX Amphibian: W/S=%.4f, W/P=%.4f, AR=%.4f\n', ...
        out.WS_lb_ft2, out.WP_lb_shp, out.aspect_ratio);
    fprintf('MTOW basis payload with full fuel: %.0f lb (ramp-based full-fuel payload differs)\n', ...
        out.full_fuel_payload_at_MTOW_lb);
end
