from __future__ import annotations

import math
from typing import Any

from SeaplaneAero_Concept4 import isa_atmosphere
from constraint_cruise_speed_C4 import constraint_cruise_speed

KT_FPS = 1.687809857
HP_TO_KW = 0.7456998715822702


def _required_climb_hp(
    weight_lb: float,
    area_ft2: float,
    alt_ft: float,
    roc_fpm: float,
    aero: Any,
    eta_p: float,
    speed_samples: int
):
    rho = isa_atmosphere(alt_ft)["rho_slug_ft3"]

    polar = aero.get_config_polar(
        {"alt_ft": alt_ft, "ktas": 110.0},
        {"config": "clean"}
    )

    clmax = polar["CLmax"] - aero.CL_stall_margin

    if clmax <= 0:
        raise ValueError("CLmax - stall margin must be positive")

    v_stall_fps = math.sqrt(
        2 * weight_lb / (rho * area_ft2 * clmax)
    )

    v_min = max(45.0 * KT_FPS, 1.15 * v_stall_fps)
    v_max = max(185.0 * KT_FPS, v_min + 50 * KT_FPS)

    best = None

    for i in range(speed_samples):
        v = v_min + (v_max - v_min) * i / (speed_samples - 1)
        q = 0.5 * rho * v * v
        cl = weight_lb / (q * area_ft2)

        if cl > clmax:
            continue

        cd = polar["CD0"] + polar["K1"] * cl * cl
        d_lb = q * area_ft2 * cd

        hp = (
            d_lb * v + weight_lb * roc_fpm / 60.0
        ) / (550.0 * eta_p)

        if best is None or hp < best["hp"]:
            best = {
                "hp": hp,
                "speed_ktas": v / KT_FPS,
                "CL": cl,
                "CD0": polar["CD0"]
            }

    return best


def matching_envelope(
    J: dict,
    geom: Any,
    aero: Any,
    prop: Any,
    weight_lb: float,
    assumptions: dict
) -> dict:

    scan = J["constraints"]

    lo, hi = map(
        float,
        scan["wing_loading_range_psf"]
    )

    n = int(
        assumptions["design_constraint_wing_loading_points"]
    )

    speeds = int(
        assumptions["design_constraint_speed_samples"]
    )

    if n < 3 or speeds < 3:
        raise ValueError(
            "Need >=3 wing loadings and speed samples"
        )

    span_cap = float(
        J["rfp_performance_requirements"][
            "maximum_wingspan_ft_strictly_below"
        ]
    )

    motor_frac = prop.motor_continuous_fraction
    eta_p = prop.eta_p_climb

    phi = float(
        J["propulsion"]["phi"].get("climb", 0.4)
    )

    generator_eff = (
        prop.eta_generator * prop.eta_rectifier
    )

    gen_lapse = prop.generator_lapse_exponent

    design_span = span_cap - float(
        assumptions.get("span_design_margin_ft", 1.0)
    )

    if design_span <= 0:
        raise ValueError("Invalid span design margin")

    lo = max(
        lo,
        weight_lb * float(geom.AR) / (design_span * design_span)
    )

    results = []
    save_s = geom.S_ref

    try:
        for i in range(n) if lo <= hi else []:
            ws = lo + (hi - lo) * i / (n - 1)
            area = weight_lb / ws

            geom.S_ref = area

            if geom.b >= span_cap:
                continue

            r0 = _required_climb_hp(
                weight_lb,
                area,
                0,
                2000,
                aero,
                eta_p,
                speeds
            )

            r10 = _required_climb_hp(
                weight_lb,
                area,
                10000,
                500,
                aero,
                eta_p,
                speeds
            )

            roei = _required_climb_hp(
                weight_lb,
                area,
                0,
                450,
                aero,
                eta_p,
                speeds
            )

            cruise = constraint_cruise_speed(
                weight_lb,
                area,
                10000,
                180,
                aero,
                prop.eta_p_cruise
            )

            if any(
                x is None for x in (r0, r10, roei, cruise)
            ):
                continue

            p_motor = max(
                r0["hp"] / motor_frac,
                r10["hp"] / motor_frac,
                cruise["hp"] / motor_frac,
                roei["hp"] / motor_frac
                * prop.n_motors / (prop.n_motors - 1)
            )

            p_motor *= (
                1.0
                + float(
                    assumptions.get(
                        "motor_power_margin_fraction",
                        0.01
                    )
                )
            )

            def gen_rating_from_shaft(
                shaft_hp,
                altitude_ft,
                bus_fraction
            ):
                kw = (
                    prop.motor_bus_kw(shaft_hp)
                    * bus_fraction
                )

                sigma = prop.sigma_isa(altitude_ft)

                total_engine_hp = (
                    kw / (generator_eff * HP_TO_KW)
                    / sigma ** gen_lapse
                )

                return total_engine_hp / prop.n_generators

            p_gen = max(
                gen_rating_from_shaft(
                    cruise["hp"],
                    10000,
                    1.0
                ),
                gen_rating_from_shaft(
                    r0["hp"],
                    0,
                    1.0 - phi
                ),
                gen_rating_from_shaft(
                    r10["hp"],
                    10000,
                    1.0 - phi
                )
            ) * (
                1.0
                + assumptions["generator_power_margin_fraction"]
            )

            score = (
                p_motor
                + 0.15 * p_gen
                + 0.20 * area
            )

            results.append({
                "wing_loading_psf": ws,
                "wing_area_ft2": area,
                "span_ft": geom.b,
                "required_motor_hp": p_motor,
                "required_turboshaft_hp_each": p_gen,
                "cruise_180_hp": cruise["hp"],
                "roc_2000_sl_hp": r0["hp"],
                "roc_500_10k_hp": r10["hp"],
                "roc_450_oei_hp_NO_FAILURE_DRAG": roei["hp"],
                "score": score
            })

    finally:
        geom.S_ref = save_s

    if not results:
        return {
            "status": "NO_FEASIBLE_AERODYNAMIC_POINT_WITHIN_WING_LOADING_SWEEP",
            "candidates": [],
            "selected": None
        }

    chosen = min(
        results,
        key=lambda c: c["score"]
    )

    return {
        "status": "PRELIMINARY_AERO_AND_SPAN_ONLY",
        "selected": chosen,
        "candidates": results,
        "unverified": [
            "Water takeoff and landing within 2000 ft over 50-ft obstacle",
            "OEI with stopped-prop drag and yaw control; current estimate omits it",
            "Generator-out contingency and electric-only takeoff/landing sizing",
            "Balked landing reserve energy and hydrostatic flood/heel requirements"
        ]
    }
