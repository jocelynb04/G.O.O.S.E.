function verify_openvsp_geometry()
%VERIFY_OPENVSP_GEOMETRY Check imported dimensions through the normal model entry point.
    obj = ttpa_disciplines();
    g = obj.geom;
    r = g.openvsp_reference;
    assert(abs(g.S_ref - r.wing_area_ft2) < 1e-8);
    assert(abs(g.b - r.wing_span_ft) < 1e-8);
    assert(abs(g.MAC - r.wing_mac_ft) < 1e-8);
    assert(abs(g.S_v_tail - 45) < 1e-8);
    assert(abs(g.b_v_tail - 18) < 1e-8);
    assert(abs(g.c_root_v_tail - 4) < 1e-8);
    assert(abs(g.c_tip_v_tail - 1) < 1e-8);
    assert(abs(g.MAC_v_tail - 2.8) < 1e-8);
    assert(abs(g.S_v_tail_horizontal - 22.5) < 1e-8);
    assert(abs(g.S_v_tail_vertical - 22.5) < 1e-8);
    assert(abs(g.dihedral_v_tail_deg - 45) < 1e-8);
    assert(abs(g.l_fus - 50) < 1e-8);
    expected_wet = r.wing_wet_ft2 + r.tail_wet_ft2 + r.fuselage_wet_ft2 ...
        + r.nacelle_wet_ft2 + 2*r.float_wet_each_ft2 + r.float_strut_wet_ft2;
    assert(abs(g.S_wet - expected_wet) < 1e-8);
    assert(abs(obj.aero.CD0 - obj.aero.Cfe*expected_wet/g.S_ref) < 1e-10);
    assert(obj.prop.n_motors == size(r.propeller_positions_ft, 1));
    baseline_area = g.S_ref;
    g.S_ref = baseline_area*1.1;
    assert(abs(g.S_v_tail - 49.5) < 1e-8);
    assert(abs(g.S_wet_wing - r.wing_wet_ft2*1.1) < 1e-8);
    assert(abs(g.S_wet_fuselage - r.fuselage_wet_ft2) < 1e-8);
    g.S_ref = baseline_area;
    a = matchingdiagram();
    assert(all(isfinite(a.WP_envelope)));
    assert(abs(a.concept3_design_point.wing_loading_psf ...
        - obj.sizing.W_TO_guess_lbf/g.S_ref) < 1e-8);
    bd = obj.wts.OEW_breakdown(obj.sizing.W_TO_guess_lbf);
    assert(abs(bd.float_struts - obj.wts.rho_wing*g.S_float_struts) < 1e-8);
    assert(isfinite(bd.total) && bd.total > 0);
    fprintf('OpenVSP geometry checks passed. Span %.3f ft, wing %.3f ft^2, tail %.3f ft^2, CD0 %.5f.\n', ...
        g.b, g.S_ref, g.S_v_tail, obj.aero.CD0);
end
