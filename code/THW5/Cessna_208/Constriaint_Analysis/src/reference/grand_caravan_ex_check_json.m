function out = grand_caravan_ex_check_json(json_path)
%GRAND_CARAVAN_EX_CHECK_JSON  Read-only input sanity check without framework.
    if nargin == 0
        json_path = ttpa_requirements_path();
    end
    J = jsondecode(fileread(json_path));
    p = grand_caravan_ex_params();
    assert(J.caravan.enabled && J.propulsion.n_engines == 1, 'EX mode and 1 engine required');
    assert(abs(J.caravan.reference_power_shp-867) < 1e-10,'Wrong engine baseline');
    assert(abs(J.geometry.AR - p.AR) < 1e-8,'Wrong wing AR');
    assert(abs(J.sizing.W_TO_guess_lbf-9062) < 1e-10,'Wrong takeoff weight');
    assert(all(arrayfun(@(c) ~isfield(c,'oei') || ~isequal(c.oei,true), ...
        J.constraints.conditions)),'Multi-engine OEI constraint remains');
    out = grand_caravan_ex_benchmark();
    out.demo_mission_range_nm = J.design_range_nmi;
    segments = J.missions.std_mission.segments;

    if iscell(segments)
        cruise = segments{3};
    else
        cruise = segments(3);
    end

        out.demo_mission_cruise_KTAS = cruise.ktas;
    end
