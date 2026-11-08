
"""Concept 4 equivalent of IHW3 segment_climb_L2.m speed/power calculation.

The IHW3 excess-power altitude-band method is retained, but fuel and SOC
must be calculated by SeaplaneProp.power_balance, not piston C_bhp.
"""
from math import sqrt
from SeaplaneAero_Concept4 import isa_atmosphere

KNOT_FPS = 1.687809857

class MissionInfeasible(RuntimeError):
    pass

def best_climb_power(weight_lb, altitude_ft, roc_fpm, aero, eta_p, *, config="clean"):
    """Minimize required shaft horsepower over a speed sweep, enforcing CLmax."""
    if roc_fpm <= 0 or not 0 < eta_p <= 1:
        raise ValueError("Climb ROC and propeller efficiency must be positive")
    rho = isa_atmosphere(altitude_ft)["rho_slug_ft3"]
    clmax = aero.get_config_polar(None, {"config": config})["CLmax"]
    vs_fps = sqrt(2 * weight_lb / (rho * aero.geom.S_ref * clmax))
    min_knots = max(45.0, 1.20 * vs_fps / KNOT_FPS)
    max_knots = max(180.0, min_knots + 45.0)
    candidates = []
    for i in range(35):
        speed_kt = min_knots + (max_knots - min_knots) * i / 34
        forces = aero.flight_forces(weight_lb, speed_kt, altitude_ft, config=config)
        if forces["CL_limit_exceeded"]:
            continue
        power_hp = (
            forces["drag_lb"] * speed_kt * KNOT_FPS
            + weight_lb * roc_fpm / 60.0
        ) / (550.0 * eta_p)
        candidates.append((power_hp, speed_kt, forces["CL"], forces["L_over_D"]))
    if not candidates:
        raise MissionInfeasible("No valid climb speed above stall")
    power_hp, speed_kt, cl, ld = min(candidates)
    return {"shaft_hp": power_hp, "ktas": speed_kt, "CL": cl, "L_over_D": ld}