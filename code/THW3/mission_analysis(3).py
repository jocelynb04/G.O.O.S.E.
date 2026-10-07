"""Tidal Flight mission sizing for the Philippines island-hopping mission.

The analysis keeps the original assignment approach:
  * ordered mission segments;
  * Breguet relations for cruise and loiter;
  * power x time fuel/energy accounting for repeated short segments;
  * iterative takeoff-weight closure using the team aero, propulsion, and
    weights models.

Five cases are evaluated: the two independently fueled Philippines
dispatches, direct Seattle-to-Ketchikan and New York-to-Washington comparison
missions, and the long-range RFP mission. The aircraft is sized to the case
that produces the greatest takeoff weight.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from Weights import TidalWeights
from seaplane_prop import SeaplaneProp
from ttpa_aero import TtpaAero


KNOT_TO_FPS = 1.687809857
NM_TO_MI = 1.15077945
HP_TO_FTLBF_S = 550.0


# Approximate straight-line distances from the selected route study.
# The code sums the legs instead of hard-coding a rounded route total.
PHILIPPINES_ROUTE = [
    ("Manila", "Donsol", 183.0),
    ("Donsol", "Cebu City", 156.0),
    ("Cebu City", "Puerto Princesa", 306.0),
    ("Puerto Princesa", "El Nido", 96.0),
    ("El Nido", "Coron", 67.0),
    ("Coron", "Manila", 163.0),
]

# Direct coastal comparison route supplied by the route study figure.
SEATTLE_KETCHIKAN_ROUTE = [
    ("Seattle", "Ketchikan", 590.0),
]

NYC_DC_ROUTE = [
    ("New York City", "Washington, DC", 200.0),
]

# Selected preliminary design from the route/constraint trade.  These are
# design choices, not replacements for the hard RFP requirements below.
SELECTED_DESIGN = {
    "wing_area_ft2": 350.0,
    "aspect_ratio": 8.0,
    "installed_power_hp": 1350.0,
    "route_cruise_altitude_ft": 4000.0,
    "takeoff_time_min": 2.0,
    "landing_time_min": 2.0,
    "maximum_takeoff_weight_lb": 12500.0,
}

@dataclass
class MissionResult:
    profile: str
    description: str
    segments: list[dict[str, Any]]
    legs: list[dict[str, Any]]
    route_distance_nm: float
    block_time_hr: float
    mission_fuel_lb: float
    reserve_fuel_lb: float
    total_fuel_lb: float
    battery_required_Wh: float
    battery_weight_lb: float
    shore_recharge_Wh: float
    landing_weight_lb: float


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def apply_selected_design(requirements: dict[str, Any]) -> None:
    """Apply the agreed preliminary geometry, power, and route assumptions."""
    geometry = requirements["geometry"]
    geometry["AR"] = SELECTED_DESIGN["aspect_ratio"]
    geometry["S_ref_ft2"] = SELECTED_DESIGN["wing_area_ft2"]
    geometry["design_span_ft"] = math.sqrt(
        geometry["AR"] * geometry["S_ref_ft2"]
    )
    requirements["propulsion"]["P_SL_hp"] = SELECTED_DESIGN[
        "installed_power_hp"
    ]
    requirements["weights"]["maximum_takeoff_weight_lb"] = SELECTED_DESIGN[
        "maximum_takeoff_weight_lb"
    ]
    defaults = requirements.setdefault("mission_profile_defaults", {})
    defaults.update(
        {
            "cruise_altitude_ft": SELECTED_DESIGN[
                "route_cruise_altitude_ft"
            ],
            "takeoff_time_min": SELECTED_DESIGN["takeoff_time_min"],
            "landing_time_min": SELECTED_DESIGN["landing_time_min"],
            "cebu_recharge_min": 30.0,
        }
    )


def write_csv(path: Path, rows: Iterable[dict[str, Any]]) -> None:
    rows = list(rows)
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def isa_state(altitude_ft: float) -> dict[str, float]:
    """Tropospheric ISA state in English engineering units."""
    altitude_m = altitude_ft * 0.3048
    temperature_k = 288.15 - 0.0065 * altitude_m
    pressure_pa = 101325.0 * (temperature_k / 288.15) ** 5.25588
    density_kg_m3 = pressure_pa / (287.05287 * temperature_k)
    density_slug_ft3 = density_kg_m3 * 0.00194032033
    return {
        "alt_ft": altitude_ft,
        "rho_slug_ft3": density_slug_ft3,
        "sigma": density_slug_ft3 / 0.0023768924,
    }


def cruise_weight_fraction(
    distance_nm: float, c_bhp: float, eta_p: float, ld_ratio: float
) -> float:
    """Original assignment propeller-aircraft Breguet range relation."""
    distance_mi = distance_nm * NM_TO_MI
    return math.exp(-distance_mi * c_bhp / (375.0 * eta_p * ld_ratio))


def loiter_weight_fraction(
    time_min: float, speed_ktas: float, c_bhp: float, eta_p: float, ld_ratio: float
) -> float:
    """Original assignment propeller-aircraft loiter relation."""
    time_hr = time_min / 60.0
    speed_fps = speed_ktas * KNOT_TO_FPS
    return math.exp(
        -time_hr * speed_fps * c_bhp / (ld_ratio * HP_TO_FTLBF_S * eta_p)
    )


def profile_defaults(requirements: dict[str, Any]) -> dict[str, float]:
    """Central location for the few preliminary route assumptions."""
    rfp = requirements["rfp_performance_requirements"]
    user_values = requirements.get("mission_profile_defaults", {})
    return {
        "cruise_altitude_ft": float(user_values.get("cruise_altitude_ft", 10000.0)),
        "cruise_speed_ktas": float(
            user_values.get(
                "cruise_speed_ktas",
                rfp.get("mission_cruise_speed_ktas", rfp.get("cruise_speed_ktas", 130.0)),
            )
        ),
        "climb_speed_ktas": float(user_values.get("climb_speed_ktas", 100.0)),
        "climb_roc_fpm": float(user_values.get("climb_roc_fpm", 1250.0)),
        "descent_speed_ktas": float(user_values.get("descent_speed_ktas", 120.0)),
        "descent_rate_fpm": float(user_values.get("descent_rate_fpm", 1500.0)),
        "takeoff_time_min": float(user_values.get("takeoff_time_min", 3.0)),
        "landing_time_min": float(user_values.get("landing_time_min", 3.0)),
        "ordinary_turnaround_min": float(
            user_values.get("ordinary_turnaround_min", 15.0)
        ),
        "cebu_recharge_min": float(user_values.get("cebu_recharge_min", 30.0)),
        "reserve_altitude_ft": float(user_values.get("reserve_altitude_ft", 4000.0)),
        "reserve_speed_ktas": float(user_values.get("reserve_speed_ktas", 120.0)),
        "reserve_time_min": float(
            user_values.get("reserve_time_min", rfp.get("ifr_reserve_time_min", 45.0))
        ),
    }


def flight_leg_segments(
    leg_number: int,
    origin: str,
    destination: str,
    distance_nm: float,
    values: dict[str, float],
    phi: dict[str, float],
) -> list[dict[str, Any]]:
    """Create one complete water-to-water mission leg."""
    altitude = values["cruise_altitude_ft"]
    climb_time = altitude / values["climb_roc_fpm"]
    descent_time = altitude / values["descent_rate_fpm"]
    climb_distance = values["climb_speed_ktas"] * climb_time / 60.0
    descent_distance = values["descent_speed_ktas"] * descent_time / 60.0
    cruise_distance = max(0.0, distance_nm - climb_distance - descent_distance)
    common = {
        "leg_number": leg_number,
        "origin": origin,
        "destination": destination,
        "leg_distance_nm": distance_nm,
    }
    return [
        {
            **common,
            "type": "takeoff",
            "name": f"{origin}: water taxi and takeoff",
            "alt_ft": 0.0,
            "time_min": values["takeoff_time_min"],
            "distance_nm": 0.0,
            "ktas": 0.0,
            "phi": phi["takeoff"],
            "shaft_power_fraction": 0.85,
        },
        {
            **common,
            "type": "climb",
            "name": f"{origin} to cruise altitude",
            "alt_ft": altitude,
            "time_min": climb_time,
            "distance_nm": climb_distance,
            "ktas": values["climb_speed_ktas"],
            "roc_fpm": values["climb_roc_fpm"],
            "phi": phi["climb"],
        },
        {
            **common,
            "type": "cruise",
            "name": f"Cruise: {origin} to {destination}",
            "alt_ft": altitude,
            "time_min": 60.0 * cruise_distance / values["cruise_speed_ktas"],
            "distance_nm": cruise_distance,
            "ktas": values["cruise_speed_ktas"],
            "phi": phi["cruise"],
        },
        {
            **common,
            "type": "descent",
            "name": f"Descent into {destination}",
            "alt_ft": 0.0,
            "time_min": descent_time,
            "distance_nm": descent_distance,
            "ktas": values["descent_speed_ktas"],
            "phi": phi["descent"],
            "shaft_power_fraction": 0.20,
        },
    ]


def reserve_segments(
    leg_number: int,
    origin: str,
    destination: str,
    values: dict[str, float],
    phi: dict[str, float],
) -> list[dict[str, Any]]:
    """Balked landing plus the explicit 45-minute IFR reserve."""
    reserve_altitude = values["reserve_altitude_ft"]
    climb_time = reserve_altitude / values["climb_roc_fpm"]
    descent_time = reserve_altitude / values["descent_rate_fpm"]
    common = {
        "leg_number": leg_number,
        "origin": origin,
        "destination": destination,
        "leg_distance_nm": 0.0,
    }
    return [
        {
            **common,
            "type": "climb",
            "name": "Balked landing / reserve climb",
            "alt_ft": reserve_altitude,
            "time_min": climb_time,
            "distance_nm": values["climb_speed_ktas"] * climb_time / 60.0,
            "ktas": values["climb_speed_ktas"],
            "roc_fpm": values["climb_roc_fpm"],
            "phi": phi["climb"],
        },
        {
            **common,
            "type": "loiter",
            "name": "45-minute IFR reserve loiter",
            "alt_ft": reserve_altitude,
            "time_min": values["reserve_time_min"],
            "distance_nm": 0.0,
            "ktas": values["reserve_speed_ktas"],
            "phi": phi["loiter"],
        },
        {
            **common,
            "type": "descent",
            "name": "Reserve descent",
            "alt_ft": 0.0,
            "time_min": descent_time,
            "distance_nm": values["descent_speed_ktas"] * descent_time / 60.0,
            "ktas": values["descent_speed_ktas"],
            "phi": phi["descent"],
            "shaft_power_fraction": 0.20,
        },
    ]


def landing_segment(
    leg_number: int,
    origin: str,
    destination: str,
    leg_distance_nm: float,
    values: dict[str, float],
    phi: dict[str, float],
) -> dict[str, Any]:
    return {
        "leg_number": leg_number,
        "origin": origin,
        "destination": destination,
        "leg_distance_nm": leg_distance_nm,
        "type": "landing",
        "name": f"{destination}: water landing and taxi/dock",
        "alt_ft": 0.0,
        "time_min": values["landing_time_min"],
        "distance_nm": 0.0,
        "ktas": 0.0,
        "phi": phi["landing"],
        "shaft_power_fraction": 0.30,
    }


def build_dispatch_profile(
    requirements: dict[str, Any],
    name: str,
    description: str,
    route_legs: list[tuple[str, str, float]],
    leg_start: int,
    service_at_end: bool,
) -> dict[str, Any]:
    """Build one independently fueled dispatch mission with its own reserve."""
    values = profile_defaults(requirements)
    phi = requirements["propulsion"]["phi"]
    segments: list[dict[str, Any]] = []

    for leg_number, (origin, destination, distance_nm) in enumerate(
        route_legs, start=leg_start
    ):
        segments.extend(
            flight_leg_segments(
                leg_number, origin, destination, distance_nm, values, phi
            )
        )
        is_final_leg = leg_number == leg_start + len(route_legs) - 1
        if is_final_leg:
            segments.extend(
                reserve_segments(leg_number, origin, destination, values, phi)
            )
        segments.append(
            landing_segment(
                leg_number, origin, destination, distance_nm, values, phi
            )
        )

        if is_final_leg and service_at_end:
            segments.append(
                {
                    "leg_number": leg_number,
                    "origin": destination,
                    "destination": destination,
                    "leg_distance_nm": 0.0,
                    "type": "recharge",
                    "name": "Cebu City hub refuel and recharge",
                    "alt_ft": 0.0,
                    "time_min": values["cebu_recharge_min"],
                    "distance_nm": 0.0,
                    "ktas": 0.0,
                    "phi": 0.0,
                }
            )
        elif not is_final_leg:
            segments.append(
                {
                    "leg_number": leg_number,
                    "origin": destination,
                    "destination": destination,
                    "leg_distance_nm": 0.0,
                    "type": "turnaround",
                    "name": f"{destination} dock turnaround",
                    "alt_ft": 0.0,
                    "time_min": values["ordinary_turnaround_min"],
                    "distance_nm": 0.0,
                    "ktas": 0.0,
                    "phi": 0.0,
                }
            )

    return {
        "name": name,
        "description": description,
        "route_distance_nm": sum(leg[2] for leg in route_legs),
        "reserve_fuel_fraction": float(
            requirements["missions"]["std_mission"].get("reserve_fuel_fraction", 0.06)
        ),
        "segments": segments,
    }


def build_manila_to_cebu_profile(requirements: dict[str, Any]) -> dict[str, Any]:
    return build_dispatch_profile(
        requirements=requirements,
        name="Philippines dispatch: Manila to Cebu",
        description="Manila-Donsol-Cebu; independently fueled and serviced at Cebu",
        route_legs=PHILIPPINES_ROUTE[:2],
        leg_start=1,
        service_at_end=True,
    )


def build_cebu_to_manila_profile(requirements: dict[str, Any]) -> dict[str, Any]:
    return build_dispatch_profile(
        requirements=requirements,
        name="Philippines dispatch: Cebu to Manila",
        description="Cebu-Puerto Princesa-El Nido-Coron-Manila; independently fueled at Cebu",
        route_legs=PHILIPPINES_ROUTE[2:],
        leg_start=3,
        service_at_end=False,
    )


def build_seattle_to_ketchikan_profile(
    requirements: dict[str, Any],
) -> dict[str, Any]:
    """One-way 590-nmi comparison mission with the standard IFR reserve."""
    return build_dispatch_profile(
        requirements=requirements,
        name="Seattle to Ketchikan comparison",
        description=(
            "Direct Lake Union-to-Tongass Narrows flight; one-way comparison "
            "mission with no intermediate recharge"
        ),
        route_legs=SEATTLE_KETCHIKAN_ROUTE,
        leg_start=1,
        service_at_end=False,
    )


def build_nyc_to_dc_profile(requirements: dict[str, Any]) -> dict[str, Any]:
    """One-way 200-nmi comparison mission with the standard IFR reserve."""
    return build_dispatch_profile(
        requirements=requirements,
        name="NYC to Washington DC comparison",
        description=(
            "Direct New York City-to-Washington, DC flight; one-way comparison "
            "mission with no intermediate recharge"
        ),
        route_legs=NYC_DC_ROUTE,
        leg_start=1,
        service_at_end=False,
    )


def build_nonstop_profile(
    requirements: dict[str, Any], distance_nm: float | None = None
) -> dict[str, Any]:
    """Single long-range profile used for the required comparison."""
    values = profile_defaults(requirements)
    # The short island legs use 4,000 ft.  The independent RFP mission retains
    # the 10,000-ft design condition used by the original compliance mission.
    values["cruise_altitude_ft"] = float(
        requirements["rfp_performance_requirements"][
            "cruise_density_altitude_ft"
        ]
    )
    phi = requirements["propulsion"]["phi"]
    rfp = requirements["rfp_performance_requirements"]
    distance = float(
        distance_nm
        if distance_nm is not None
        else rfp.get("required_range_nmi", requirements["design_range_nmi"])
    )
    origin = "Design origin"
    destination = "Design destination"
    segments = flight_leg_segments(1, origin, destination, distance, values, phi)
    segments.extend(reserve_segments(1, origin, destination, values, phi))
    segments.append(
        landing_segment(1, origin, destination, distance, values, phi)
    )
    return {
        "name": "RFP nonstop design mission",
        "description": "Single 1,000-statute-mile mission with no shore recharge",
        "route_distance_nm": distance,
        "reserve_fuel_fraction": float(
            requirements["missions"]["std_mission"].get("reserve_fuel_fraction", 0.06)
        ),
        "segments": segments,
    }


def clean_shaft_power_hp(
    weight_lb: float,
    speed_ktas: float,
    altitude_ft: float,
    wing_area_ft2: float,
    aero: TtpaAero,
    eta_prop: float,
) -> float:
    speed_fps = speed_ktas * KNOT_TO_FPS
    state = isa_state(altitude_ft)
    q_psf = 0.5 * state["rho_slug_ft3"] * speed_fps**2
    cl = weight_lb / (q_psf * wing_area_ft2)
    cd = aero.polar_model.CD0 + aero.K * cl**2
    drag_lb = q_psf * wing_area_ft2 * cd
    return drag_lb * speed_fps / (HP_TO_FTLBF_S * eta_prop)


def segment_shaft_power_hp(
    segment: dict[str, Any],
    weight_lb: float,
    requirements: dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
) -> float:
    """Preliminary power used only to track battery energy/SOC."""
    segment_type = segment["type"]
    if segment_type in {"recharge", "turnaround"}:
        return 0.0
    if "shaft_power_fraction" in segment:
        return float(segment["shaft_power_fraction"]) * prop.P_SL

    wing_area = float(requirements["geometry"]["S_ref_ft2"])
    speed = float(segment.get("ktas", 0.0))
    altitude = float(segment.get("alt_ft", 0.0))
    if segment_type == "loiter":
        eta_prop = prop.eta_p_loiter
    elif segment_type == "climb":
        eta_prop = prop.eta_p_climb
    else:
        eta_prop = prop.eta_p_cruise
    power = clean_shaft_power_hp(
        weight_lb, speed, altitude, wing_area, aero, eta_prop
    )
    if segment_type == "climb":
        power += weight_lb * float(segment["roc_fpm"]) / 33000.0
    return min(power, prop.P_SL)


def segment_fuel_burn_lb(
    segment: dict[str, Any],
    weight_in_lb: float,
    aero: TtpaAero,
    prop: SeaplaneProp,
    shaft_power_hp: float,
) -> tuple[float, float]:
    """Return fuel burned and the effective segment weight fraction."""
    segment_type = segment["type"]
    if segment_type in {"recharge", "turnaround"}:
        return 0.0, 1.0

    if segment_type == "cruise":
        fraction = cruise_weight_fraction(
            float(segment["distance_nm"]),
            prop.C_bhp(None, segment),
            prop.prop_eff(None, segment),
            aero.LD_max,
        )
        return weight_in_lb * (1.0 - fraction), fraction

    if segment_type == "loiter":
        fraction = loiter_weight_fraction(
            float(segment["time_min"]),
            float(segment["ktas"]),
            prop.C_bhp(None, segment),
            prop.prop_eff(None, segment),
            0.866 * aero.LD_max,
        )
        return weight_in_lb * (1.0 - fraction), fraction

    # Repeating a whole-mission fixed weight fraction at every island stop
    # greatly overstates fuel.  For the repeated takeoff/climb/descent/landing
    # segments, use the teammate propulsion model directly: fuel = c_bhp P t.
    # Cruise and loiter retain the assignment's Breguet relations above.
    time_hr = float(segment.get("time_min", 0.0)) / 60.0
    fuel_burn = prop.C_bhp(None, segment) * shaft_power_hp * time_hr
    return fuel_burn, 1.0 - fuel_burn / weight_in_lb


def run_profile(
    takeoff_weight_lb: float,
    profile: dict[str, Any],
    requirements: dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
) -> MissionResult:
    """Fly one ordered profile and track fuel, battery deficit, and recharge."""
    current_weight = takeoff_weight_lb
    battery_deficit_Wh = 0.0
    peak_battery_deficit_Wh = 0.0
    shore_recharge_Wh = 0.0
    rows: list[dict[str, Any]] = []
    leg_starts: dict[int, float] = {}
    leg_fuel: dict[int, float] = {}
    leg_energy: dict[int, float] = {}
    leg_time: dict[int, float] = {}
    for number, original in enumerate(profile["segments"], start=1):
        segment = dict(original)
        segment_type = segment["type"]
        leg_number = int(segment.get("leg_number", 0))
        weight_in = current_weight
        time_hr = float(segment.get("time_min", 0.0)) / 60.0

        if leg_number and leg_number not in leg_starts:
            leg_starts[leg_number] = weight_in
        if segment_type == "recharge":
            recharge_Wh = battery_deficit_Wh
            shore_recharge_Wh += recharge_Wh
            battery_deficit_Wh = 0.0
            fuel_used = 0.0
            weight_fraction = 1.0
            battery_delta_Wh = 0.0
            shaft_power_hp = 0.0
        else:
            shaft_power_hp = segment_shaft_power_hp(
                segment, weight_in, requirements, aero, prop
            )
            fuel_used, weight_fraction = segment_fuel_burn_lb(
                segment, weight_in, aero, prop, shaft_power_hp
            )
            current_weight -= fuel_used
            phi = float(prop.get_phi(segment)) if segment_type != "turnaround" else 0.0
            battery_delta_Wh = (
                prop.battery_Wh_per_hphr(phi) * shaft_power_hp * time_hr
            )
            # Negative phi recharges in flight.  The pack cannot exceed 100% SOC.
            battery_deficit_Wh = max(0.0, battery_deficit_Wh + battery_delta_Wh)
            peak_battery_deficit_Wh = max(
                peak_battery_deficit_Wh, battery_deficit_Wh
            )
            recharge_Wh = 0.0

        if leg_number:
            leg_fuel[leg_number] = leg_fuel.get(leg_number, 0.0) + fuel_used
            leg_energy[leg_number] = leg_energy.get(leg_number, 0.0) + max(
                0.0, battery_delta_Wh
            )
            leg_time[leg_number] = leg_time.get(leg_number, 0.0) + time_hr

        rows.append(
            {
                "segment_number": number,
                "leg_number": leg_number,
                "origin": segment.get("origin", ""),
                "destination": segment.get("destination", ""),
                "segment": segment["name"],
                "type": segment_type,
                "altitude_ft": float(segment.get("alt_ft", 0.0)),
                "speed_ktas": float(segment.get("ktas", 0.0)),
                "distance_nm": float(segment.get("distance_nm", 0.0)),
                "time_min": float(segment.get("time_min", 0.0)),
                "weight_in_lb": weight_in,
                "weight_fraction": weight_fraction,
                "fuel_used_lb": fuel_used,
                "weight_out_lb": current_weight,
                "phi_battery_share": float(segment.get("phi", 0.0)),
                "shaft_power_hp": shaft_power_hp,
                "battery_delta_kWh": battery_delta_Wh / 1000.0,
                "battery_deficit_kWh": battery_deficit_Wh / 1000.0,
                "shore_recharge_kWh": recharge_Wh / 1000.0,
            }
        )

    battery_weight = (
        prop.battery_weight(peak_battery_deficit_Wh)
        if peak_battery_deficit_Wh > 0.0
        else 0.0
    )
    usable_energy = max(peak_battery_deficit_Wh, 1.0)
    for row in rows:
        row["battery_soc_percent"] = max(
            0.0, 100.0 * (1.0 - 1000.0 * row["battery_deficit_kWh"] / usable_energy)
        )

    mission_fuel = sum(float(row["fuel_used_lb"]) for row in rows)
    reserve_fuel = float(profile["reserve_fuel_fraction"]) * mission_fuel

    legs: list[dict[str, Any]] = []
    route_legs = [
        segment
        for segment in profile["segments"]
        if segment["type"] == "cruise" and int(segment.get("leg_number", 0)) > 0
    ]
    for segment in route_legs:
        leg_number = int(segment["leg_number"])
        end_rows = [row for row in rows if int(row["leg_number"]) == leg_number]
        legs.append(
            {
                "profile": profile["name"],
                "leg_number": leg_number,
                "origin": segment["origin"],
                "destination": segment["destination"],
                "distance_nm": float(segment["leg_distance_nm"]),
                "takeoff_weight_lb": leg_starts[leg_number],
                "arrival_weight_lb": float(end_rows[-1]["weight_out_lb"]),
                "fuel_used_lb": leg_fuel.get(leg_number, 0.0),
                "battery_discharge_kWh": leg_energy.get(leg_number, 0.0) / 1000.0,
                "elapsed_time_hr": leg_time.get(leg_number, 0.0),
                "recharge_at_destination": segment["destination"] == "Cebu City",
            }
        )

    return MissionResult(
        profile=profile["name"],
        description=profile["description"],
        segments=rows,
        legs=legs,
        route_distance_nm=float(profile["route_distance_nm"]),
        block_time_hr=sum(float(row["time_min"]) for row in rows) / 60.0,
        mission_fuel_lb=mission_fuel,
        reserve_fuel_lb=reserve_fuel,
        total_fuel_lb=mission_fuel + reserve_fuel,
        battery_required_Wh=peak_battery_deficit_Wh,
        battery_weight_lb=battery_weight,
        shore_recharge_Wh=shore_recharge_Wh,
        landing_weight_lb=current_weight,
    )


def size_profile(
    profile: dict[str, Any],
    requirements: dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
    weights: TidalWeights,
) -> tuple[float, MissionResult, list[dict[str, Any]]]:
    settings = requirements["weights"]
    guess = float(settings.get("initial_takeoff_weight_lb", 12000.0))
    tolerance = float(settings.get("sizing_tolerance_lb", 0.1))
    max_iterations = int(settings.get("sizing_max_iterations", 100))
    history: list[dict[str, Any]] = []

    for iteration in range(1, max_iterations + 1):
        mission = run_profile(guess, profile, requirements, aero, prop)
        empty_weight = weights.OEW(guess)
        new_weight = (
            empty_weight
            + weights.W_payload_fixed
            + weights.W_payload_expendable
            + mission.total_fuel_lb
            + mission.battery_weight_lb
        )
        difference = new_weight - guess
        history.append(
            {
                "profile": profile["name"],
                "iteration": iteration,
                "weight_guess_lb": guess,
                "empty_weight_lb": empty_weight,
                "payload_lb": weights.W_payload_fixed,
                "mission_fuel_lb": mission.mission_fuel_lb,
                "reserve_fuel_lb": mission.reserve_fuel_lb,
                "battery_energy_kWh": mission.battery_required_Wh / 1000.0,
                "battery_weight_lb": mission.battery_weight_lb,
                "weight_new_lb": new_weight,
                "difference_lb": difference,
            }
        )
        if abs(difference) <= tolerance:
            final_mission = run_profile(
                new_weight, profile, requirements, aero, prop
            )
            return new_weight, final_mission, history
        guess = new_weight

    raise RuntimeError(
        f"{profile['name']} did not converge in {max_iterations} iterations."
    )


def payload_range_rows(
    takeoff_weight_lb: float,
    requirements: dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
    weights: TidalWeights,
    points: int = 31,
) -> list[dict[str, float]]:
    """Retain the assignment's simple fixed-MTOW payload-range trade."""
    design_range = float(requirements["rfp_performance_requirements"]["required_range_nmi"])
    empty_weight = weights.OEW(takeoff_weight_lb)
    selected_payload = weights.W_payload_fixed
    rows: list[dict[str, float]] = []
    for index in range(points):
        distance = 1.35 * design_range * index / (points - 1)
        profile = build_nonstop_profile(requirements, distance)
        mission = run_profile(
            takeoff_weight_lb, profile, requirements, aero, prop
        )
        payload_by_weight = max(
            0.0,
            takeoff_weight_lb
            - empty_weight
            - mission.total_fuel_lb
            - mission.battery_weight_lb,
        )
        rows.append(
            {
                "range_nm": distance,
                "payload_lb": min(selected_payload, payload_by_weight),
                "fuel_with_reserve_lb": mission.total_fuel_lb,
                "battery_weight_lb": mission.battery_weight_lb,
            }
        )
    return rows


def plot_results(
    output_dir: Path,
    profile_rows: list[dict[str, Any]],
    payload_rows: list[dict[str, float]],
) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return

    fig, axis = plt.subplots(figsize=(8.5, 5.0))
    axis.bar(
        [row["profile"] for row in profile_rows],
        [row["takeoff_weight_lb"] for row in profile_rows],
        color=["tab:blue", "tab:orange", "tab:green", "tab:red", "tab:purple"],
    )
    axis.axhline(
        float(profile_rows[0]["mtow_limit_lb"]),
        color="tab:red",
        linestyle="--",
        linewidth=1.8,
        label="12,500-lb MTOW limit",
    )
    axis.set_ylabel("Converged takeoff weight (lb)")
    axis.set_title("Mission Sizing Comparison")
    axis.grid(axis="y", alpha=0.25)
    axis.tick_params(axis="x", rotation=10)
    axis.legend(loc="upper left")
    fig.tight_layout()
    fig.savefig(output_dir / "mission_profile_comparison.png", dpi=180)
    plt.close(fig)

    fig, axis = plt.subplots(figsize=(8.5, 5.0))
    axis.plot(
        [row["range_nm"] for row in payload_rows],
        [row["payload_lb"] for row in payload_rows],
        linewidth=2.5,
    )
    axis.set_xlabel("Nonstop range (nmi)")
    axis.set_ylabel("Payload (lb)")
    axis.set_title("Preliminary payload-range trade")
    axis.grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(output_dir / "payload_range.png", dpi=180)
    plt.close(fig)


def plot_philippines_mission_profile(
    output_dir: Path, requirements: dict[str, Any]
) -> None:
    """Draw the ordered Manila-to-Manila route as a simple mission schematic."""
    try:
        import matplotlib.pyplot as plt
        from matplotlib.lines import Line2D
    except ImportError:
        return

    values = profile_defaults(requirements)
    cruise_altitude = values["cruise_altitude_ft"]
    climb_distance = (
        values["climb_speed_ktas"]
        * cruise_altitude
        / values["climb_roc_fpm"]
        / 60.0
    )
    descent_distance = (
        values["descent_speed_ktas"]
        * cruise_altitude
        / values["descent_rate_fpm"]
        / 60.0
    )

    fig, axis = plt.subplots(figsize=(14.0, 7.4))
    cumulative_distance = 0.0
    endpoint_distances = [0.0]

    for leg_index, (origin, destination, distance_nm) in enumerate(
        PHILIPPINES_ROUTE, start=1
    ):
        leg_start = cumulative_distance
        leg_end = leg_start + distance_nm
        color = "#1f77b4" if leg_index <= 2 else "#e87523"
        axis.plot(
            [
                leg_start,
                leg_start + climb_distance,
                leg_end - descent_distance,
                leg_end,
            ],
            [0.0, cruise_altitude, cruise_altitude, 0.0],
            color=color,
            linewidth=2.8,
            solid_capstyle="round",
        )
        leg_label_altitude = cruise_altitude + (460.0 if leg_index == 5 else 210.0)
        axis.text(
            0.5 * (leg_start + leg_end),
            leg_label_altitude,
            f"Leg {leg_index}: {distance_nm:.0f} nmi",
            ha="center",
            va="bottom",
            fontsize=9,
            color=color,
            weight="bold",
        )
        cumulative_distance = leg_end
        endpoint_distances.append(cumulative_distance)

    route_total = cumulative_distance
    city_names = [PHILIPPINES_ROUTE[0][0]] + [leg[1] for leg in PHILIPPINES_ROUTE]
    for index, (distance_nm, city) in enumerate(
        zip(endpoint_distances, city_names)
    ):
        axis.scatter(distance_nm, 0.0, s=38, color="#17324d", zorder=5)
        axis.axvline(distance_nm, color="#808080", linewidth=0.8, alpha=0.25)
        label_y = -420.0 if index % 2 == 0 else -760.0
        axis.annotate(
            city,
            xy=(distance_nm, 0.0),
            xytext=(distance_nm, label_y),
            ha="center",
            va="top",
            fontsize=9,
            weight="bold" if city in {"Manila", "Cebu City"} else "normal",
            arrowprops=dict(arrowstyle="-", color="#808080", linewidth=0.8),
        )

    cebu_distance = endpoint_distances[2]
    axis.annotate(
        "Cebu hub\n30-min refuel + recharge",
        xy=(cebu_distance, 0.0),
        xytext=(cebu_distance + 18.0, 1350.0),
        ha="left",
        va="center",
        fontsize=9.5,
        color="#5a3d00",
        bbox=dict(boxstyle="round,pad=0.35", facecolor="#fff1b8", edgecolor="#c89416"),
        arrowprops=dict(arrowstyle="->", color="#c89416", linewidth=1.4),
    )

    # The reserve is drawn after the route solely as a schematic; its horizontal
    # length is not included in the 971-nmi island-route total.
    reserve_start = route_total + 18.0
    reserve_climb_end = reserve_start + 18.0
    reserve_loiter_end = reserve_climb_end + 58.0
    reserve_end = reserve_loiter_end + 18.0
    axis.axvspan(route_total + 8.0, reserve_end + 8.0, color="#f3f3f3", zorder=0)
    axis.plot(
        [reserve_start, reserve_climb_end, reserve_loiter_end, reserve_end],
        [0.0, cruise_altitude, cruise_altitude, 0.0],
        color="#666666",
        linewidth=2.4,
        linestyle="--",
    )
    axis.text(
        0.5 * (reserve_climb_end + reserve_loiter_end),
        cruise_altitude + 210.0,
        "45-min IFR reserve",
        ha="center",
        va="bottom",
        fontsize=9,
        color="#555555",
        weight="bold",
    )
    axis.text(
        0.5 * (reserve_start + reserve_end),
        850.0,
        "Balked landing, climb, loiter, descent\n(schematic; not route distance)",
        ha="center",
        va="center",
        fontsize=8.5,
        color="#555555",
    )

    axis.text(
        0.5 * route_total,
        -1220.0,
        (
            f"Total island route: {route_total:.0f} nmi   |   "
            "Dispatch 1: 339 nmi   |   Dispatch 2: 632 nmi"
        ),
        ha="center",
        va="top",
        fontsize=10,
        weight="bold",
        color="#17324d",
    )
    axis.text(
        0.5 * endpoint_distances[2],
        5100.0,
        "DISPATCH 1",
        ha="center",
        fontsize=10,
        color="#1f77b4",
        weight="bold",
    )
    axis.text(
        0.5 * (endpoint_distances[2] + route_total),
        5100.0,
        "DISPATCH 2",
        ha="center",
        fontsize=10,
        color="#e87523",
        weight="bold",
    )

    axis.set_xlim(-18.0, reserve_end + 12.0)
    axis.set_ylim(-1500.0, 5500.0)
    axis.set_xlabel("Cumulative Philippines route distance (nmi)")
    axis.set_ylabel("Altitude (ft)")
    axis.set_title("Philippines Island-Hopping Mission Profile", weight="bold")
    axis.set_yticks([0, 1000, 2000, 3000, 4000, 5000])
    axis.set_xticks(endpoint_distances)
    axis.grid(axis="y", alpha=0.22)
    axis.spines[["top", "right"]].set_visible(False)
    axis.legend(
        handles=[
            Line2D([0], [0], color="#1f77b4", lw=2.8, label="Manila to Cebu"),
            Line2D([0], [0], color="#e87523", lw=2.8, label="Cebu to Manila"),
            Line2D([0], [0], color="#666666", lw=2.4, ls="--", label="Final reserve"),
        ],
        loc="upper right",
        framealpha=0.95,
    )
    fig.tight_layout()
    fig.savefig(output_dir / "mission_profile_philippines.png", dpi=200)
    plt.close(fig)


def print_report(profile_rows: list[dict[str, Any]], route_legs: list[dict[str, Any]]) -> None:
    print("\nMISSION PROFILE COMPARISON")
    print("=" * 112)
    print(
        f"{'Profile':<35} {'Range':>9} {'Time':>9} {'Fuel':>11} "
        f"{'Battery':>11} {'Batt Wt':>11} {'W_TO':>11} {'MTOW':>7} {'Driver':>8}"
    )
    for row in profile_rows:
        print(
            f"{row['profile']:<35} {row['route_distance_nm']:9.1f} "
            f"{row['block_time_hr']:9.2f} {row['fuel_carried_lb']:11.1f} "
            f"{row['battery_required_kWh']:11.1f} {row['battery_weight_lb']:11.1f} "
            f"{row['takeoff_weight_lb']:11.1f} {row['mtow_status']:>7} "
            f"{row['design_driver']:>8}"
        )

    print("\nOPERATIONAL ROUTE LEGS")
    print("=" * 100)
    print(
        f"{'Leg':>3} {'Origin':<18} {'Destination':<18} {'nmi':>7} "
        f"{'W_TO':>11} {'Fuel':>10} {'Time hr':>9} {'Recharge':>10}"
    )
    for row in route_legs:
        print(
            f"{row['leg_number']:3d} {row['origin']:<18} {row['destination']:<18} "
            f"{row['distance_nm']:7.1f} {row['takeoff_weight_lb']:11.1f} "
            f"{row['fuel_used_lb']:10.1f} {row['elapsed_time_hr']:9.2f} "
            f"{str(row['recharge_at_destination']):>10}"
        )


def write_summary(
    path: Path,
    profile_rows: list[dict[str, Any]],
    route_legs: list[dict[str, Any]],
) -> None:
    driver = next(row for row in profile_rows if row["design_driver"] == "YES")
    philippines_legs = [
        row
        for row in route_legs
        if row["profile"].startswith("Philippines dispatch:")
    ]
    route_total = sum(float(row["distance_nm"]) for row in philippines_legs)
    lines = [
        "# Tidal Flight mission-analysis summary",
        "",
        "## Selected operational mission",
        "",
        "- Route: Manila -> Donsol -> Cebu City -> Puerto Princesa -> El Nido -> Coron -> Manila.",
        f"- Calculated route distance from rounded legs: **{route_total:,.0f} nmi**.",
        "- The route is divided into two independent dispatch missions at Cebu City.",
        "- The aircraft is refueled and recharged at Cebu; battery mass remains onboard.",
        "- Operational island legs cruise at 4,000 ft; the independent RFP mission retains 10,000 ft.",
        "- Each leg contains water taxi/takeoff, climb, cruise, descent, and water landing/taxi.",
        "- The final return to Manila includes a balked landing and 45-minute IFR reserve.",
        "- Comparison route: Seattle (Lake Union) -> Ketchikan (Tongass Narrows), 590 nmi one way.",
        "- The Seattle-Ketchikan case has no intermediate recharge and includes the same 45-minute IFR reserve.",
        "- Comparison route: New York City -> Washington, DC, 200 nmi one way.",
        "- The NYC-DC case has no intermediate recharge and includes the same 45-minute IFR reserve.",
        "",
        "## Sizing decision",
        "",
        f"- Driving profile: **{driver['profile']}**.",
        f"- Design takeoff weight: **{driver['takeoff_weight_lb']:,.1f} lb**.",
        f"- Fuel carried: **{driver['fuel_carried_lb']:,.1f} lb**.",
        f"- Required usable battery energy between recharges: **{driver['battery_required_kWh']:,.1f} kWh**.",
        f"- Estimated battery weight: **{driver['battery_weight_lb']:,.1f} lb**.",
        f"- MTOW compliance: **{driver['mtow_status']}** against the 12,500-lb limit.",
        "",
        "The two Philippines dispatches, Seattle-Ketchikan and NYC-DC comparisons, and nonstop RFP mission are evaluated with the same team weight, aerodynamic, and propulsion models. The highest converged takeoff weight is passed to constraint analysis.",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--requirements",
        type=Path,
        default=Path(__file__).with_name("tidal_requirements.json"),
    )
    parser.add_argument(
        "--output", type=Path, default=Path(__file__).with_name("results")
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    requirements = load_json(args.requirements)
    apply_selected_design(requirements)
    args.output.mkdir(parents=True, exist_ok=True)

    aero = TtpaAero(str(args.requirements))
    prop = SeaplaneProp(requirements)
    weights = TidalWeights(str(args.requirements))
    prop.P_SL = float(requirements["propulsion"]["P_SL_hp"])

    profiles = [
        build_manila_to_cebu_profile(requirements),
        build_cebu_to_manila_profile(requirements),
        build_seattle_to_ketchikan_profile(requirements),
        build_nyc_to_dc_profile(requirements),
        build_nonstop_profile(requirements),
    ]
    sized: list[tuple[float, MissionResult, list[dict[str, Any]]]] = []
    for profile in profiles:
        sized.append(size_profile(profile, requirements, aero, prop, weights))

    design_weight = max(item[0] for item in sized)
    profile_rows: list[dict[str, Any]] = []
    all_segments: list[dict[str, Any]] = []
    all_legs: list[dict[str, Any]] = []
    all_iterations: list[dict[str, Any]] = []

    for takeoff_weight, mission, iterations in sized:
        is_driver = math.isclose(takeoff_weight, design_weight, rel_tol=0.0, abs_tol=0.05)
        mtow_limit = float(requirements["weights"]["maximum_takeoff_weight_lb"])
        profile_rows.append(
            {
                "profile": mission.profile,
                "description": mission.description,
                "route_distance_nm": mission.route_distance_nm,
                "block_time_hr": mission.block_time_hr,
                "mission_fuel_lb": mission.mission_fuel_lb,
                "reserve_fuel_lb": mission.reserve_fuel_lb,
                "fuel_carried_lb": mission.total_fuel_lb,
                "battery_required_kWh": mission.battery_required_Wh / 1000.0,
                "battery_weight_lb": mission.battery_weight_lb,
                "shore_recharge_kWh": mission.shore_recharge_Wh / 1000.0,
                "takeoff_weight_lb": takeoff_weight,
                "landing_weight_lb": mission.landing_weight_lb,
                "sizing_iterations": len(iterations),
                "mtow_limit_lb": mtow_limit,
                "mtow_status": "PASS" if takeoff_weight <= mtow_limit else "FAIL",
                "design_driver": "YES" if is_driver else "NO",
            }
        )
        all_segments.extend(
            {"profile": mission.profile, **row} for row in mission.segments
        )
        all_legs.extend(mission.legs)
        all_iterations.extend(iterations)

    route_legs = [
        row
        for row in all_legs
        if not row["profile"].startswith("RFP nonstop")
    ]
    payload_rows = payload_range_rows(
        design_weight, requirements, aero, prop, weights
    )

    write_csv(args.output / "mission_profile_summary.csv", profile_rows)
    write_csv(args.output / "mission_segments.csv", all_segments)
    write_csv(args.output / "mission_legs.csv", all_legs)
    write_csv(args.output / "sizing_iterations.csv", all_iterations)
    write_csv(args.output / "payload_range.csv", payload_rows)
    plot_results(args.output, profile_rows, payload_rows)
    write_summary(args.output / "analysis_summary.md", profile_rows, route_legs)
    (args.output / "mission_summary.json").write_text(
        json.dumps(
            {
                "design_takeoff_weight_lb": design_weight,
                "design_driver": next(
                    row["profile"]
                    for row in profile_rows
                    if row["design_driver"] == "YES"
                ),
                "maximum_takeoff_weight_lb": requirements["weights"][
                    "maximum_takeoff_weight_lb"
                ],
                "selected_design": SELECTED_DESIGN,
                "profiles": profile_rows,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print_report(profile_rows, route_legs)
    print(f"\nResults saved to: {args.output.resolve()}")

if __name__ == "__main__":
    main()
