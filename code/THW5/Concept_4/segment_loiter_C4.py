from segment_cruise_C4 import segment_cruise_C4


def segment_loiter_C4(weight_lb, speed_ktas, altitude_ft, aero, eta_p):
    return segment_cruise_C4(
        weight_lb,
        speed_ktas,
        altitude_ft,
        aero,
        eta_p
    )
