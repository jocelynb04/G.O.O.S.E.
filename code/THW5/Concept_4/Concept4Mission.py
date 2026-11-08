
from __future__ import annotations

from typing import Any

from SeaplaneProp_Concept4 import PowerUnavailableError
from segment_climb_C4 import best_climb_power, MissionInfeasible
from segment_cruise_C4 import segment_cruise_C4
from segment_loiter_C4 import segment_loiter_C4


class Concept4Mission:
    def __init__(self, J: dict, geom: Any, aero: Any, prop: Any, assumptions: dict):
        self.J = J
        self.geom = geom
        self.aero = aero
        self.prop = prop
        self.assumptions = assumptions

    def run(
        self,
        takeoff_weight_lb: float,
        *,
        mission_name="std_mission",
        sizing_probe=False
    ) -> dict:
        profile = self.J["missions"][mission_name]
        soc = self.prop.battery_initial_soc
        W = float(takeoff_weight_lb)
        alt = 0.0
        total_fuel = 0.0
        cume = 0.0
        peak_deficit = 0.0
        peak_discharge_bus = 0.0
        peak_charge_bus = 0.0
        rows = []

        original_capacity = self.prop.battery_capacity_kwh

        if sizing_probe:
            self.prop.battery_capacity_kwh = max(original_capacity, 100000.0)

        try:
            def account(
                phase,
                duration_hr,
                power_hp,
                altitude_ft,
                *,
                target=None,
                speed_kt=None,
                name=None,
                motor_rating="continuous"
            ):
                nonlocal soc, W, total_fuel, cume, peak_deficit
                nonlocal peak_discharge_bus, peak_charge_bus

                before = soc

                try:
                    r = self.prop.power_balance(
                        shaft_power_hp=power_hp,
                        duration_hr=duration_hr,
                        altitude_ft=altitude_ft,
                        phase=phase,
                        soc=soc,
                        battery_share_target=target,
                        motor_rating=motor_rating
                    )

                except (PowerUnavailableError, ValueError) as exc:
                    raise MissionInfeasible(
                        f"{name or phase}: {exc} "
                        f"(W={W:.0f} lb, SOC={before:.3f}, hp={power_hp:.0f})"
                    ) from exc

                soc = r.soc_end
                W -= r.fuel_burn_lb

                if W <= 0:
                    raise MissionInfeasible(
                        "Mission burns more fuel than gross weight"
                    )

                total_fuel += r.fuel_burn_lb
                cume += r.pack_energy_change_kwh

                peak_deficit = max(peak_deficit, cume)
                peak_discharge_bus = max(
                    peak_discharge_bus,
                    r.battery_bus_kw
                )
                peak_charge_bus = max(
                    peak_charge_bus,
                    -r.battery_bus_kw
                )

                row = {
                    "name": name or phase,
                    "phase": phase,
                    "altitude_ft": altitude_ft,
                    "speed_ktas": speed_kt,
                    "duration_min": duration_hr * 60,
                    "shaft_power_hp": power_hp,
                    "fuel_burn_lb": r.fuel_burn_lb,
                    "weight_end_lb": W,
                    "soc_start": r.soc_start,
                    "soc_end": soc,
                    "battery_bus_kw": r.battery_bus_kw,
                    "generator_bus_kw": r.generator_bus_kw,
                    "pack_energy_change_kwh": r.pack_energy_change_kwh,
                    "battery_deficit_from_initial_kwh": cume,
                    "electric_only": r.electric_only
                }

                rows.append(row)

            for seg in profile["segments"]:
                phase = seg["type"]
                name = seg.get("name", phase)
                target_alt = float(seg.get("alt_ft", alt))
                battery_target = seg.get("phi")

                if phase in (
                    "taxi",
                    "takeoff",
                    "landing",
                    "water_maneuver"
                ):
                    a = self.assumptions["ground_phases"][phase]

                    minutes = seg.get("duration_min")

                    if minutes is None:
                        minutes = a["duration_min"]

                    power = a["shaft_hp"]

                    account(
                        phase,
                        float(minutes) / 60,
                        power,
                        target_alt,
                        target=battery_target,
                        name=name,
                        motor_rating=(
                            "takeoff"
                            if phase == "takeoff"
                            else "continuous"
                        )
                    )

                    alt = target_alt

                elif phase in ("climb", "balked_landing"):
                    if target_alt <= alt:
                        raise MissionInfeasible(
                            f"{name}: target climb altitude "
                            f"{target_alt} <= {alt}"
                        )

                    n = int(profile.get("climb_segments", 8))

                    climb_rate = float(
                        self.assumptions[
                            "balked_landing_climb_fpm"
                            if phase == "balked_landing"
                            else "nominal_climb_fpm"
                        ]
                    )

                    dh = (target_alt - alt) / n
                    start_alt = alt

                    for i in range(n):
                        hmid = start_alt + (i + 0.5) * dh

                        cfg = (
                            "landing_flaps_gear_up"
                            if phase == "balked_landing"
                            else "clean"
                        )

                        optimum = best_climb_power(
                            W,
                            hmid,
                            climb_rate,
                            self.aero,
                            self.prop.eta_p_climb,
                            config=cfg
                        )

                        account(
                            phase,
                            dh / climb_rate / 60,
                            optimum["shaft_hp"],
                            hmid,
                            target=battery_target,
                            speed_kt=optimum["ktas"],
                            name=f"{name} [{i + 1}/{n}]",
                            motor_rating=(
                                "takeoff"
                                if phase == "balked_landing"
                                else "continuous"
                            )
                        )

                    alt = target_alt

                elif phase in ("cruise", "loiter"):
                    speed = float(seg["ktas"])

                    if phase == "cruise":
                        n = int(profile.get("cruise_segments", 12))
                        total_hr = float(seg["distance_nm"]) / speed

                    else:
                        n = max(
                            1,
                            int(self.assumptions["loiter_subsegments"])
                        )
                        total_hr = float(seg["time_min"]) / 60.0

                    eta = (
                        self.prop.eta_p_cruise
                        if phase == "cruise"
                        else self.prop.eta_p_loiter
                    )

                    calculator = (
                        segment_cruise_C4
                        if phase == "cruise"
                        else segment_loiter_C4
                    )

                    for i in range(n):
                        try:
                            required = calculator(
                                W,
                                speed,
                                target_alt,
                                self.aero,
                                eta
                            )

                        except ValueError as exc:
                            raise MissionInfeasible(
                                f"{name}: {exc}"
                            ) from exc

                        hp = required["shaft_hp"]

                        account(
                            phase,
                            total_hr / n,
                            hp,
                            target_alt,
                            target=battery_target,
                            speed_kt=speed,
                            name=f"{name} [{i + 1}/{n}]"
                        )

                    alt = target_alt

                elif phase == "descent":
                    duration = self.assumptions["descent_duration_min"]

                    account(
                        "descent",
                        duration / 60.0,
                        0.0,
                        target_alt,
                        target=battery_target,
                        name=name
                    )

                    alt = target_alt

                else:
                    raise MissionInfeasible(
                        f"Unsupported mission phase: {phase}"
                    )

            usable_soc = (
                self.prop.battery_initial_soc
                - self.prop.battery_min_soc
            )

            capacity_required = (
                peak_deficit / usable_soc
                if usable_soc > 0
                else float("inf")
            )

            return {
                "status": (
                    "ENERGY_SIZING_PROBE_ONLY"
                    if sizing_probe
                    else "INTEGRATED_MISSION_RUN_UNVERIFIED_ASSUMPTIONS"
                ),
                "mission_name": mission_name,
                "gross_weight_start_lb": takeoff_weight_lb,
                "total_fuel_lb": total_fuel,
                "weight_end_lb": W,
                "soc_end": soc,
                "peak_cumulative_pack_deficit_kwh": peak_deficit,
                "minimum_battery_capacity_kwh_for_soc_window": capacity_required,
                "peak_battery_discharge_bus_kw": peak_discharge_bus,
                "peak_battery_charge_bus_kw": peak_charge_bus,
                "segments": rows,
                "notes": [
                    "Ground-run power/time, descent power and climb rates are illustrative assumptions.",
                    "Water hump drag, 2000-ft water obstacle and battery thermal derating are not modeled.",
                    "BSFC is a constant unvalidated turboshaft placeholder; no engine map."
                ]
            }

        finally:
            self.prop.battery_capacity_kwh = original_capacity