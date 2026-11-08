from __future__ import annotations

from Concept4Constraints import matching_envelope


def summarize(J, sizing_result, solver):
    rfp = J["rfp_performance_requirements"]
    state = sizing_result["state"]
    final = sizing_result.get("final") or {}
    flight = final.get("mission") or {}

    solver._write_design(state)

    match = matching_envelope(
        J,
        solver.geom,
        solver.aero,
        solver.prop,
        state["W_TO_lb"],
        solver.assumptions
    )

    selected = match["selected"]
    motor = state["motor_shaft_hp"]
    eta_motor = solver.prop.motor_continuous_fraction
    actual_gen = solver.prop.generator_available_bus_kw(10000.0)

    speed_180_bus = (
        solver.prop.motor_bus_kw(selected["cruise_180_hp"])
        if selected
        else None
    )

    checks = {
        "payload": {
            "status": "MODELED_REQUIREMENT_INPUT_ONLY",
            "target_lb": 2430.0,
            "modeled_lb": solver.weights.payload()
        },

        "minimum_range_and_45_min_IFR_reserve": {
            "status": (
                "MISSION_MODELED_UNVERIFIED_ASSUMPTIONS"
                if flight
                else "NOT_ASSESSED"
            ),
            "nominal_cruise_distance_nm": 868.976,
            "reserve_min": 45.0,
            "balked_landing_explicit": True,
            "mission_fuel_lb": flight.get("total_fuel_lb"),
            "soc_end": flight.get("soc_end")
        },

        "wingspan_strictly_below_65_ft": {
            "status": (
                "PRELIMINARY_GEOMETRY_PASS"
                if mission and mission["wingspan_ft"] < 65.0
                else "NOT_VERIFIED"
            ),
            "modeled_wingspan_ft": mission.get("wingspan_ft")
        },

        "180_KTAS_at_10000ft_MTOW": {
            "status": (
                "PRELIMINARY_POWER_SCREEN_PASS"
                if selected
                and selected["cruise_180_hp"] <= motor * eta_motor
                and speed_180_bus <= actual_gen
                else "PRELIMINARY_POWER_SCREEN_FAIL"
            ),
            "shaft_hp_required": (
                selected["cruise_180_hp"] if selected else None
            ),
            "generator_bus_available_kw": actual_gen,
            "motor_bus_required_kw": speed_180_bus
        },

        "best_ROC_2000fpm_MSL": {
            "status": (
                "PRELIMINARY_POWER_SCREEN_PASS"
                if selected
                and selected["roc_2000_sl_hp"] <= motor * eta_motor
                else "PRELIMINARY_POWER_SCREEN_FAIL"
            ),
            "shaft_hp_required": (
                selected["roc_2000_sl_hp"] if selected else None
            )
        },

        "best_ROC_500fpm_10000ft": {
            "status": (
                "PRELIMINARY_POWER_SCREEN_PASS"
                if selected
                and selected["roc_500_10k_hp"] <= motor * eta_motor
                else "PRELIMINARY_POWER_SCREEN_FAIL"
            ),
            "shaft_hp_required": (
                selected["roc_500_10k_hp"] if selected else None
            )
        },

        "one_motor_out_450fpm_MSL": {
            "status": "NOT_VERIFIED_STOPPED_PROP_DRAG_AND_YAW_MISSING",
            "optimistic_shaft_hp_required": (
                selected["roc_450_oei_hp_NO_FAILURE_DRAG"]
                if selected
                else None
            )
        },

        "water_takeoff_2000ft_over_50ft": {
            "status": "NOT_VERIFIED_HUMP_AND_ACCELERATION_MISSING"
        },

        "water_landing_2000ft_over_50ft": {
            "status": "NOT_VERIFIED_WATER_LANDING_MODEL_MISSING"
        },

        "buoyancy_80pct_below_cabin_floor": {
            "status": mission.get(
                "buoyancy", {}
            ).get(
                "rfp_below_cabin_floor_screen",
                "NOT_ASSESSED"
            )
        },

        "two_adjacent_compartments_flooded": {
            "status": "NOT_VERIFIED"
        },

        "heel_20deg_and_gust_40kt": {
            "status": "NOT_VERIFIED"
        },

        "generator_failure_and_energy_contingency": {
            "status": "NOT_VERIFIED"
        },

        "no_external_shore_charging": {
            "status": "NOT_VERIFIED_OPERATIONAL_RECHARGE"
        },

        "dock_clearance_6ft": {
            "status": "NOT_VERIFIED"
        },

        "crosswind_water_land_20kt": {
            "status": "NOT_VERIFIED"
        },

        "turnaround_at_most_30_min": {
            "status": "NOT_VERIFIED"
        },

        "sea_state_3_reliability_above_98pct": {
            "status": "NOT_VERIFIED"
        },

        "IFR_and_FIKI": {
            "status": "NOT_VERIFIED"
        },

        "passenger_cabin_seats_and_egress": {
            "status": "NOT_VERIFIED"
        },

        "noise_80dB_desirable": {
            "status": "NOT_EVALUATED_DESIRABLE_NOT_MANDATORY"
        },

        "weight_energy_power_convergence": {
            "status": sizing_result["status"],
            "mass_residual_lb": mission.get(
                "mass_closure_residual_lb"
            )
        }
    }

    return {
        "summary_status": "PRELIMINARY_SCREENS_ONLY_NOT_RFP_COMPLIANT",
        "checks": checks,
        "note": (
            "Numerical convergence does NOT establish aircraft "
            "feasibility or certification compliance."
        )
    }
