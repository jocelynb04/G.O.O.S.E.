
"""Port of IHW3 drag-based cruise-speed constraint for series-hybrid use.

This returns required motor shaft HP; the matching model separately checks
motor continuous rating and turbogenerator electrical-bus capability.
"""
import math
from SeaplaneAero_Concept4 import isa_atmosphere

KT_FPS = 1.687809857


def constraint_cruise_speed(weight_lb, area_ft2, altitude_ft, speed_ktas, aero, eta_p):
    rho = isa_atmosphere(altitude_ft)["rho_slug_ft3"]
    v = speed_ktas * KT_FPS
    q = 0.5 * rho * v * v

    p = aero.get_config_polar(
        {"alt_ft": altitude_ft, "ktas": speed_ktas},
        {"config": "clean"}
    )

    cl = weight_lb / (q * area_ft2)

    if cl > p["CLmax"]:
        return None

    cd = p["CD0"] + p["K1"] * cl * cl
    drag = q * area_ft2 * cd

    return {
        "hp": drag * v / (550.0 * eta_p),
        "drag_lb": drag,
        "CL": cl,
        "L_over_D": cl / cd
    }
