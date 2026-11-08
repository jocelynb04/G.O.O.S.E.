KNOT_FPS = 1.687809857


def segment_cruise_C4(weight_lb, speed_ktas, altitude_ft, aero, eta_p):
    forces = aero.flight_forces(
        weight_lb,
        speed_ktas,
        altitude_ft,
        config="clean"
    )

    if forces["CL_limit_exceeded"]:
        raise ValueError(
            f"Lift demand exceeds clean CLmax at {speed_ktas} KTAS"
        )

    shaft_hp = (
        forces["drag_lb"] * speed_ktas * KNOT_FPS
        / (550 * eta_p)
    )

    return {
        "shaft_hp": shaft_hp,
        "CL": forces["CL"],
        "L_over_D": forces["L_over_D"],
        "drag_lb": forces["drag_lb"]
    }
