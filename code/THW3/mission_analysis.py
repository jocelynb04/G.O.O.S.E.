"""Integrated Tidal Flight mission analysis and preliminary flight performance.

"""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

from Weights import TidalWeights
from seaplane_prop import SeaplaneProp
from ttpa_aero import TtpaAero


KNOT_TO_FPS = 1.687809857
NM_TO_MI = 1.15077945
HP_TO_FTLBF_S = 550.0
HP_MIN_TO_FTLBF = 33000.0


@dataclass
class MissionResult:
    segments: List[Dict[str, float | str]]
    mission_fuel_lb: float
    reserve_fuel_lb: float
    total_fuel_lb: float
    landing_weight_lb: float


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def write_csv(path: Path, rows: Iterable[Dict[str, Any]]) -> None:
    rows = list(rows)
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def isa_state(alt_ft: float) -> Dict[str, float]:
    """Return tropospheric ISA density state in English engineering units."""
    alt_m = alt_ft * 0.3048
    t0_k = 288.15
    p0_pa = 101325.0
    lapse_k_m = 0.0065
    gas_constant = 287.05287
    gravity = 9.80665
    temperature_k = t0_k - lapse_k_m * alt_m
    pressure_pa = p0_pa * (temperature_k / t0_k) ** (
        gravity / (gas_constant * lapse_k_m)
    )
    density_kg_m3 = pressure_pa / (gas_constant * temperature_k)
    density_slug_ft3 = density_kg_m3 * 0.00194032033
    rho0_slug_ft3 = 0.0023768924
    return {
        "alt_ft": alt_ft,
        "temperature_k": temperature_k,
        "pressure_pa": pressure_pa,
        "rho_slug_ft3": density_slug_ft3,
        "sigma": density_slug_ft3 / rho0_slug_ft3,
    }


def simple_weight_fraction(weight_fraction: float, weight_in_lb: float) -> Tuple[float, float]:
    fuel_used_lb = (1.0 - weight_fraction) * weight_in_lb
    return weight_in_lb - fuel_used_lb, fuel_used_lb


def cruise_weight_fraction(
    distance_nm: float, c_bhp: float, eta_p: float, ld_ratio: float
) -> float:
    """Propeller-aircraft Breguet range equation used in run_mission.m."""
    distance_mi = distance_nm * NM_TO_MI
    return math.exp(-distance_mi * c_bhp / (375.0 * eta_p * ld_ratio))


def loiter_weight_fraction(
    time_min: float, speed_ktas: float, c_bhp: float, eta_p: float, ld_ratio: float
) -> float:
    """Propeller loiter equation used in run_mission.m."""
    time_hr = time_min / 60.0
    speed_fps = speed_ktas * KNOT_TO_FPS
    return math.exp(
        -time_hr * speed_fps * c_bhp / (ld_ratio * HP_TO_FTLBF_S * eta_p)
    )

def run_mission(
    weight_takeoff_lb: float,
    requirements: Dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
    distance_override_nm: Optional[float] = None,
) -> MissionResult:
    """Run the ordered mission using the supplied MATLAB segment methods."""
    mission = requirements["missions"]["std_mission"]
    fixed_wf = requirements["legacy_segment_weight_fractions"]
    current_weight_lb = weight_takeoff_lb
    rows: List[Dict[str, float | str]] = []

    for number, original_segment in enumerate(mission["segments"], start=1):
        segment = dict(original_segment)
        segment_type = segment["type"]
        if segment_type == "cruise" and distance_override_nm is not None:
            segment["distance_nm"] = float(distance_override_nm)

        weight_in_lb = current_weight_lb
        if segment_type in ("takeoff", "climb", "descent", "landing"):
            weight_fraction = float(fixed_wf[segment_type])
        elif segment_type == "cruise":
            weight_fraction = cruise_weight_fraction(
                distance_nm=float(segment["distance_nm"]),
                c_bhp=prop.C_bhp(None, segment),
                eta_p=prop.prop_eff(None, segment),
                ld_ratio=aero.LD_max,
            )
        elif segment_type == "loiter":
            weight_fraction = loiter_weight_fraction(
                time_min=float(segment["time_min"]),
                speed_ktas=float(segment["ktas"]),
                c_bhp=prop.C_bhp(None, segment),
                eta_p=prop.prop_eff(None, segment),
                ld_ratio=0.866 * aero.LD_max,
            )
        else:
            raise ValueError(f"Unsupported mission segment type: {segment_type}")

        current_weight_lb, fuel_used_lb = simple_weight_fraction(
            weight_fraction, weight_in_lb
        )
        reported_distance_nm = float(segment.get("distance_nm", 0.0))
        if segment_type == "loiter" and reported_distance_nm == 0.0:
            # Loiter has no point-to-point range, but the aircraft still
            # travels this approximate air distance during the hold.
            reported_distance_nm = (
                float(segment["ktas"]) * float(segment["time_min"]) / 60.0
            )
        rows.append(
            {
                "segment_number": number,
                "segment": str(segment.get("name", segment_type)),
                "type": segment_type,
                "altitude_ft": float(segment.get("alt_ft", 0.0)),
                "speed_ktas": float(segment.get("ktas", 0.0)),
                "distance_nm": reported_distance_nm,
                "time_min": float(segment.get("time_min", 0.0)),
                "weight_in_lb": weight_in_lb,
                "weight_fraction": weight_fraction,
                "fuel_used_lb": fuel_used_lb,
                "weight_out_lb": current_weight_lb,
            }
        )

    mission_fuel_lb = sum(float(row["fuel_used_lb"]) for row in rows)
    reserve_fraction = float(mission["reserve_fuel_fraction"])
    reserve_fuel_lb = reserve_fraction * mission_fuel_lb
    return MissionResult(
        segments=rows,
        mission_fuel_lb=mission_fuel_lb,
        reserve_fuel_lb=reserve_fuel_lb,
        total_fuel_lb=mission_fuel_lb + reserve_fuel_lb,
        landing_weight_lb=current_weight_lb,
    )


def size_takeoff_weight(
    requirements: Dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
    weights: TidalWeights,
    initial_weight_lb: float = 12000.0,
    tolerance_lb: float = 0.1,
    max_iterations: int = 100,
) -> Tuple[float, MissionResult, List[Dict[str, float]]]:
    """Close W_TO = OEW + fixed payload + fuel (including 6% reserve)."""
    guess_lb = initial_weight_lb
    history: List[Dict[str, float]] = []

    for iteration in range(1, max_iterations + 1):
        mission = run_mission(guess_lb, requirements, aero, prop)
        empty_weight_lb = weights.OEW(guess_lb)
        new_weight_lb = (
            empty_weight_lb + weights.W_payload_fixed + mission.total_fuel_lb
        )
        difference_lb = new_weight_lb - guess_lb
        history.append(
            {
                "iteration": iteration,
                "weight_guess_lb": guess_lb,
                "empty_weight_lb": empty_weight_lb,
                "payload_lb": weights.W_payload_fixed,
                "mission_fuel_lb": mission.mission_fuel_lb,
                "reserve_fuel_lb": mission.reserve_fuel_lb,
                "total_fuel_lb": mission.total_fuel_lb,
                "weight_new_lb": new_weight_lb,
                "difference_lb": difference_lb,
                "difference_percent": 100.0 * difference_lb / guess_lb,
            }
        )
        if abs(difference_lb) <= tolerance_lb:
            final_weight_lb = new_weight_lb
            final_mission = run_mission(final_weight_lb, requirements, aero, prop)
            return final_weight_lb, final_mission, history
        guess_lb = new_weight_lb

    raise RuntimeError(
        f"Takeoff-weight sizing did not converge in {max_iterations} iterations."
    )

def payload_range_rows(
    takeoff_weight_lb: float,
    requirements: Dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
    weights: TidalWeights,
    max_range_nm: Optional[float] = None,
    points: int = 31,
) -> List[Dict[str, float]]:
    """Preliminary fixed-MTOW payload-range weight-exchange calculation."""
    design_range_nm = float(requirements["design_range_nmi"])
    max_range_nm = max_range_nm or 1.35 * design_range_nm
    empty_weight_lb = weights.OEW(takeoff_weight_lb)
    selected_payload_lb = weights.W_payload_fixed
    result: List[Dict[str, float]] = []

    for index in range(points):
        distance_nm = max_range_nm * index / (points - 1)
        mission = run_mission(
            takeoff_weight_lb,
            requirements,
            aero,
            prop,
            distance_override_nm=distance_nm,
        )
        payload_by_weight_lb = max(
            0.0, takeoff_weight_lb - empty_weight_lb - mission.total_fuel_lb
        )
        payload_limited_lb = min(selected_payload_lb, payload_by_weight_lb)
        result.append(
            {
                "range_nm": distance_nm,
                "range_statute_mi": distance_nm * NM_TO_MI,
                "payload_lb": payload_limited_lb,
                "weight_exchange_payload_lb": payload_by_weight_lb,
                "fuel_with_reserve_lb": mission.total_fuel_lb,
            }
        )
    return result

def clean_power_required_hp(
    weight_lb: float,
    wing_area_ft2: float,
    speed_ktas: float,
    state: Dict[str, float],
    aero: TtpaAero,
    eta_prop: float,
) -> Tuple[float, float, float, float]:
    speed_fps = speed_ktas * KNOT_TO_FPS
    q_psf = 0.5 * state["rho_slug_ft3"] * speed_fps**2
    cl = weight_lb / (q_psf * wing_area_ft2)
    cd = aero.polar_model.CD0 + aero.K * cl**2
    drag_lb = q_psf * wing_area_ft2 * cd
    power_hp = drag_lb * speed_fps / (HP_TO_FTLBF_S * eta_prop)
    return power_hp, cl, cd, drag_lb

def performance_analysis(
    weight_lb: float,
    requirements: Dict[str, Any],
    aero: TtpaAero,
    prop: SeaplaneProp,
    wing_area_ft2: Optional[float],
    power_sl_hp: Optional[float],
    clmax_clean: Optional[float],
) -> Tuple[List[Dict[str, float]], Dict[str, Any]]:
    missing = []
    if wing_area_ft2 is None:
        missing.append("S_ref_ft2 / --wing-area")
    if power_sl_hp is None:
        missing.append("P_SL_hp / --power-hp")
    if clmax_clean is None:
        missing.append("CLmax_clean / --clmax-clean")
    if missing:
        return [], {"status": "NOT EVALUATED", "missing_inputs": missing}

    assert wing_area_ft2 is not None
    assert power_sl_hp is not None
    assert clmax_clean is not None
    prop.P_SL = power_sl_hp
    rfp = requirements["rfp_performance_requirements"]
    rows: List[Dict[str, float]] = []
    summary: Dict[str, Any] = {"status": "EVALUATED"}

    for altitude_ft in (0.0, float(rfp["cruise_density_altitude_ft"])):
        state = isa_state(altitude_ft)
        eta_prop = prop.eta_p_cruise
        available_hp = power_sl_hp * prop.power_lapse(
            state, rating="takeoff", source="fuel"
        )
        stall_fps = math.sqrt(
            2.0 * weight_lb
            / (state["rho_slug_ft3"] * wing_area_ft2 * clmax_clean)
        )
        stall_ktas = stall_fps / KNOT_TO_FPS
        start_speed = max(1.20 * stall_ktas, 40.0)
        best_roc_fpm = -math.inf
        best_roc_speed_ktas = math.nan
        max_level_speed_ktas = math.nan

        for step in range(311):
            speed_ktas = start_speed + step
            power_required_hp, cl, cd, drag_lb = clean_power_required_hp(
                weight_lb,
                wing_area_ft2,
                speed_ktas,
                state,
                aero,
                eta_prop,
            )
            excess_power_hp = available_hp - power_required_hp
            roc_fpm = HP_MIN_TO_FTLBF * excess_power_hp / weight_lb
            if roc_fpm > best_roc_fpm:
                best_roc_fpm = roc_fpm
                best_roc_speed_ktas = speed_ktas
            if excess_power_hp >= 0.0:
                max_level_speed_ktas = speed_ktas
            rows.append(
                {
                    "altitude_ft": altitude_ft,
                    "speed_ktas": speed_ktas,
                    "stall_speed_ktas": stall_ktas,
                    "CL": cl,
                    "CD": cd,
                    "drag_lb": drag_lb,
                    "power_required_hp": power_required_hp,
                    "power_available_hp": available_hp,
                    "rate_of_climb_fpm": roc_fpm,
                }
            )

        summary[f"stall_speed_{int(altitude_ft)}ft_ktas"] = stall_ktas
        summary[f"best_roc_{int(altitude_ft)}ft_fpm"] = best_roc_fpm
        summary[f"best_roc_speed_{int(altitude_ft)}ft_ktas"] = best_roc_speed_ktas
        summary[f"max_level_speed_{int(altitude_ft)}ft_ktas"] = max_level_speed_ktas
        summary["cruise_target_ktas"] = float(
            rfp["required_cruise_capability_ktas"]
        )

    tenk_state = isa_state(float(rfp["cruise_density_altitude_ft"]))
    cruise_required_hp, _, _, _ = clean_power_required_hp(
        weight_lb,
        wing_area_ft2,
        float(rfp["required_cruise_capability_ktas"]),
        tenk_state,
        aero,
        prop.eta_p_cruise,
    )
    cruise_available_hp = power_sl_hp * prop.power_lapse(
        tenk_state, rating="takeoff", source="fuel"
    )
    sea_level_available_hp = power_sl_hp * prop.power_lapse(
        isa_state(0.0), rating="takeoff", source="fuel"
    )
    sea_level_best_required_hp = sea_level_available_hp - (
        summary["best_roc_0ft_fpm"] * weight_lb / HP_MIN_TO_FTLBF
    )
    oei_available_hp = sea_level_available_hp * (prop.n_engines - 1) / prop.n_engines
    summary.update(
        {
            "wing_area_ft2": wing_area_ft2,
            "span_ft": math.sqrt(requirements["geometry"]["AR"] * wing_area_ft2),
            "power_sl_hp": power_sl_hp,
            "clmax_clean": clmax_clean,
            "maximum_operating_speed_ktas": float(
                rfp["maximum_operating_speed_ktas"]
            ),
            "cruise_180kt_10000ft_power_required_hp": cruise_required_hp,
            "cruise_180kt_10000ft_power_available_hp": cruise_available_hp,
            "cruise_180kt_10000ft_pass": cruise_required_hp <= cruise_available_hp,
            "roc_10000ft_pass": summary["best_roc_10000ft_fpm"]
            >= float(rfp["minimum_roc_10000ft_fpm"]),
            "roc_sea_level_pass": summary["best_roc_0ft_fpm"]
            >= float(rfp["minimum_roc_sea_level_fpm"]),
            "oei_best_roc_sea_level_fpm": HP_MIN_TO_FTLBF
            * (oei_available_hp - sea_level_best_required_hp)
            / weight_lb,
            "span_limit_pass": math.sqrt(
                requirements["geometry"]["AR"] * wing_area_ft2
            )
            <= float(requirements["geometry"]["span_limit_ft"]),
        }
    )
    summary["oei_roc_sea_level_pass"] = summary[
        "oei_best_roc_sea_level_fpm"
    ] >= float(rfp["minimum_oei_roc_sea_level_fpm"])
    return rows, summary

def add_climb_time_distance(
    mission_segments,
    performance_summary,
    roc_fraction=1.0,
):
    """Add calculated climb time and distance to the mission rows.

    roc_fraction = 1.0 uses the calculated best ROC.
    roc_fraction = 0.8 uses 80% of best ROC for a more conservative climb.
    """

    if performance_summary.get("status") != "EVALUATED":
        return

    roc_sl_fpm = performance_summary["best_roc_0ft_fpm"]
    roc_10000_fpm = performance_summary[
        "best_roc_10000ft_fpm"
    ]

    speed_sl_ktas = performance_summary[
        "best_roc_speed_0ft_ktas"
    ]
    speed_10000_ktas = performance_summary[
        "best_roc_speed_10000ft_ktas"
    ]

    current_altitude_ft = 0.0

    for segment in mission_segments:
        target_altitude_ft = float(segment["altitude_ft"])

        if (
            segment["type"] == "climb"
            and target_altitude_ft > current_altitude_ft
        ):
            altitude_change_ft = (
                target_altitude_ft - current_altitude_ft
            )

            average_altitude_ft = 0.5 * (
                current_altitude_ft + target_altitude_ft
            )

            # Linear interpolation between sea level and 10,000 ft.
            altitude_fraction = min(
                max(average_altitude_ft / 10000.0, 0.0),
                1.0,
            )

            best_roc_fpm = (
                roc_sl_fpm
                + altitude_fraction
                * (roc_10000_fpm - roc_sl_fpm)
            )

            climb_roc_fpm = roc_fraction * best_roc_fpm

            climb_speed_ktas = (
                speed_sl_ktas
                + altitude_fraction
                * (speed_10000_ktas - speed_sl_ktas)
            )

            # Time required to complete the climb.
            climb_time_min = (
                altitude_change_ft / climb_roc_fpm
            )

            climb_time_hr = climb_time_min / 60.0

            # Approximate horizontal distance traveled in climb.
            climb_distance_nm = (
                climb_speed_ktas * climb_time_hr
            )

            # Replace the original zero values in the mission row.
            segment["time_min"] = climb_time_min
            segment["distance_nm"] = climb_distance_nm
            segment["speed_ktas"] = climb_speed_ktas

        # The ending altitude of this segment becomes the starting
        # altitude of the next segment.
        current_altitude_ft = target_altitude_ft

def plot_payload_range(path: Path, rows: List[Dict[str, float]], requirements: Dict[str, Any]) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return

    x = [row["range_nm"] for row in rows]
    y = [row["payload_lb"] for row in rows]
    design_range = float(requirements["design_range_nmi"])
    selected_payload = float(requirements["payload"]["W_payload_fixed_lb"])

    fig, axis = plt.subplots(figsize=(8.5, 5.0))
    axis.plot(x, y, linewidth=2.5, label="Preliminary payload capability")
    axis.scatter([design_range], [selected_payload], s=55, zorder=3, label="Team design mission")
    axis.axvline(
        float(requirements["rfp_performance_requirements"]["required_range_nmi"]),
        linestyle="--",
        linewidth=1.4,
        label="RFP minimum range",
    )
    axis.set_xlabel("Cruise range (nmi)")
    axis.set_ylabel("Payload (lb)")
    axis.set_title("Tidal Flight preliminary payload-range")
    axis.grid(True, alpha=0.25)
    axis.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=180)
    plt.close(fig)


def plot_performance(path: Path, rows: List[Dict[str, float]]) -> None:
    if not rows:
        return
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return

    fig, axes = plt.subplots(1, 2, figsize=(11.5, 4.8))
    for altitude_ft in sorted({row["altitude_ft"] for row in rows}):
        altitude_rows = [row for row in rows if row["altitude_ft"] == altitude_ft]
        label = f"{altitude_ft:,.0f} ft"
        axes[0].plot(
            [row["speed_ktas"] for row in altitude_rows],
            [row["power_required_hp"] for row in altitude_rows],
            label=f"Required - {label}",
        )
        axes[0].plot(
            [row["speed_ktas"] for row in altitude_rows],
            [row["power_available_hp"] for row in altitude_rows],
            linestyle="--",
            label=f"Available - {label}",
        )
        axes[1].plot(
            [row["speed_ktas"] for row in altitude_rows],
            [row["rate_of_climb_fpm"] for row in altitude_rows],
            label=label,
        )
    axes[0].set_title("Power required and available")
    axes[0].set_xlabel("True airspeed (kt)")
    axes[0].set_ylabel("Shaft power (hp)")
    axes[1].set_title("Rate of climb")
    axes[1].set_xlabel("True airspeed (kt)")
    axes[1].set_ylabel("Rate of climb (ft/min)")
    for axis in axes:
        axis.grid(True, alpha=0.25)
        axis.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=180)
    plt.close(fig)


def plot_sizing_convergence(
    path: Path, iterations: List[Dict[str, float]]
) -> None:
    """Plot the team-model takeoff-weight iteration history."""
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        return

    x = [int(row["iteration"]) for row in iterations]
    y = [row["weight_guess_lb"] for row in iterations]
    fig, axis = plt.subplots(figsize=(7.2, 5.0))
    axis.plot(
        x,
        y,
        "o-",
        linewidth=2.0,
        markersize=6,
        markerfacecolor="none",
    )
    axis.set_title("Aircraft Sizing Convergence", fontweight="bold")
    axis.set_xlabel("Iteration")
    axis.set_ylabel("Takeoff Gross Weight [lb]")
    axis.grid(True, alpha=0.35)
    fig.tight_layout()
    fig.savefig(path, dpi=180)
    plt.close(fig)


def print_team_analysis_report(
    final_weight_lb: float,
    mission: MissionResult,
    iterations: List[Dict[str, float]],
    weights: TidalWeights,
    performance: Dict[str, Any],
    output_dir: Path,
) -> None:
    """Print MATLAB-style tables using the integrated teammate models."""
    final_empty_weight_lb = weights.OEW(final_weight_lb)

    print("\nSIZING CONVERGED")
    print("=" * 117)
    print("SIZING ITERATION HISTORY - INTEGRATED TEAM MODELS")
    print("=" * 117)
    print(
        f"{'Iteration':>9} {'WTO_lb':>12} {'OEW_lb':>12} "
        f"{'Payload_lb':>12} {'MissionFuel_lb':>16} "
        f"{'TotalFuel_lb':>14} {'NewWTO_lb':>12} {'Difference_lb':>15}"
    )
    for row in iterations:
        print(
            f"{int(row['iteration']):9d} "
            f"{row['weight_guess_lb']:12.1f} "
            f"{row['empty_weight_lb']:12.1f} "
            f"{row['payload_lb']:12.1f} "
            f"{row['mission_fuel_lb']:16.1f} "
            f"{row['total_fuel_lb']:14.1f} "
            f"{row['weight_new_lb']:12.1f} "
            f"{row['difference_lb']:15.3f}"
        )

    print("\n" + "=" * 76)
    print("FINAL AIRCRAFT RESULTS - INTEGRATED TEAM MODELS")
    print("=" * 76)
    print(f"Takeoff Gross Weight = {final_weight_lb:12.2f} lb")
    print(f"Operating Empty Wt   = {final_empty_weight_lb:12.2f} lb")
    print(f"Fixed Payload Weight = {weights.W_payload_fixed:12.2f} lb")
    print(f"Mission Fuel         = {mission.mission_fuel_lb:12.2f} lb")
    print(f"Reserve Fuel         = {mission.reserve_fuel_lb:12.2f} lb")
    print(f"Fuel + Reserve       = {mission.total_fuel_lb:12.2f} lb")
    print(f"Landing Weight       = {mission.landing_weight_lb:12.2f} lb")

    print("\n" + "=" * 111)
    print("MISSION SEGMENT RESULTS - INTEGRATED TEAM MODELS")
    print("=" * 111)
    print(
        f"{'Segment':<34} {'WeightIn_lb':>13} {'WeightOut_lb':>14} "
        f"{'FuelUsed_lb':>13} {'WF':>10} {'Time_hr':>10} {'Distance_nm':>12}"
    )
    for row in mission.segments:
        speed_ktas = float(row["speed_ktas"])
        distance_nm = float(row["distance_nm"])
        if speed_ktas > 0.0 and distance_nm > 0.0:
            time_hr = distance_nm / speed_ktas
        else:
            time_hr = float(row["time_min"]) / 60.0
        print(
            f"{str(row['segment']):<34} "
            f"{float(row['weight_in_lb']):13.1f} "
            f"{float(row['weight_out_lb']):14.1f} "
            f"{float(row['fuel_used_lb']):13.3f} "
            f"{float(row['weight_fraction']):10.6f} "
            f"{time_hr:10.4f} {distance_nm:12.1f}"
        )

    print("\n" + "=" * 76)
    print("PRELIMINARY FLIGHT PERFORMANCE - INTEGRATED TEAM MODELS")
    print("=" * 76)
    if performance.get("status") == "EVALUATED":
        wing_loading = final_weight_lb / float(performance["wing_area_ft2"])
        print(f"Wing Area              = {performance['wing_area_ft2']:10.2f} ft^2")
        print(f"Wing Loading W/S       = {wing_loading:10.2f} lb/ft^2")
        print(f"Wingspan               = {performance['span_ft']:10.2f} ft")
        print(f"Sea-Level Stall Speed  = {performance['stall_speed_0ft_ktas']:10.2f} KTAS")
        print(f"Best ROC at Sea Level  = {performance['best_roc_0ft_fpm']:10.1f} ft/min")
        print(f"Best ROC at 10,000 ft  = {performance['best_roc_10000ft_fpm']:10.1f} ft/min")
        print(f"OEI ROC at Sea Level   = {performance['oei_best_roc_sea_level_fpm']:10.1f} ft/min")
        print(f"Calculated Level Capability = {performance['max_level_speed_10000ft_ktas']:7.1f} KTAS")
        print(f"Maximum Operating Speed     = {performance['maximum_operating_speed_ktas']:7.1f} KTAS")
        print(
            f"{performance['cruise_target_ktas']:.0f}-KTAS Cruise Check  = "
            f"{'PASS' if performance['cruise_180kt_10000ft_pass'] else 'FAIL'}"
        )
        print(
            f"10,000-ft ROC Check    = "
            f"{'PASS' if performance['roc_10000ft_pass'] else 'FAIL'}"
        )
        print(
            f"Sea-Level ROC Check    = "
            f"{'PASS' if performance['roc_sea_level_pass'] else 'FAIL'}"
        )
        print(
            f"OEI ROC Check          = "
            f"{'PASS' if performance['oei_roc_sea_level_pass'] else 'FAIL'}"
        )
        print(
            f"Wingspan Check         = "
            f"{'PASS' if performance['span_limit_pass'] else 'FAIL'}"
        )
    else:
        print("Flight-performance calculation skipped. Missing inputs:")
        for item in performance["missing_inputs"]:
            print(f"  - {item}")

    print(f"\nResults saved to: {output_dir.resolve()}")


def requirement_traceability(
    requirements: Dict[str, Any],
    final_weight_lb: float,
    mission: MissionResult,
    performance: Dict[str, Any],
) -> List[Dict[str, str]]:
    rfp = requirements["rfp_performance_requirements"]
    cruise_segment = next(
        segment
        for segment in requirements["missions"]["std_mission"]["segments"]
        if segment["type"] == "cruise"
    )
    loiter_segment = next(
        segment
        for segment in requirements["missions"]["std_mission"]["segments"]
        if segment["type"] == "loiter"
    )
    rows = [
        {
            "requirement": "Range with selected payload",
            "target": f">= {rfp['required_range_nmi']:.1f} nmi",
            "analysis_value": f"{cruise_segment['distance_nm']:.1f} nmi",
            "status": "PASS" if cruise_segment["distance_nm"] >= rfp["required_range_nmi"] else "FAIL",
            "note": "The compliance mission uses the RFP range.",
        },
        {
            "requirement": "Payload",
            "target": f">= {requirements['payload']['W_payload_fixed_lb']:.0f} lb",
            "analysis_value": f"{requirements['payload']['W_payload_fixed_lb']:.0f} lb",
            "status": "PASS",
            "note": "9 passengers, their baggage, and 2 pilots per RFP.",
        },
        {
            "requirement": "IFR reserve energy",
            "target": f">= {rfp['ifr_reserve_time_min']:.0f} min",
            "analysis_value": f"{loiter_segment['time_min']:.0f} min",
            "status": "PASS" if loiter_segment["time_min"] >= rfp["ifr_reserve_time_min"] else "FAIL",
            "note": "Reserve mission includes a preceding climb representing balked landing.",
        },
        {
            "requirement": "Cruise condition",
            "target": f"{rfp['required_cruise_capability_ktas']:.0f} KTAS at {rfp['cruise_density_altitude_ft']:.0f} ft DA",
            "analysis_value": f"Mission uses {cruise_segment['ktas']:.0f} KTAS at {cruise_segment['alt_ft']:.0f} ft",
            "status": "REVIEW",
            "note": "The 130-KTAS mission cruise and the separate 180-KTAS capability check serve different purposes.",
        },
        {
            "requirement": "Zero-tailpipe-emission takeoff/landing/water operations",
            "target": "Required",
            "analysis_value": "Takeoff and landing segments set phi = 1.0",
            "status": "NOT VERIFIED",
            "note": "The segment setup represents all-electric operation, but battery energy/weight closure is not yet included in this mission sizing loop.",
        },
        {
            "requirement": "Takeoff over 50-ft obstacle",
            "target": f"<= {rfp['takeoff_distance_over_obstacle_ft']:.0f} ft",
            "analysis_value": "Not calculated",
            "status": "NOT EVALUATED",
            "note": "Requires wing area, CLmax, installed power, propeller/static-thrust, and water-run model.",
        },
    ]

    if performance.get("status") == "EVALUATED":
        rows.extend(
            [
                {
                    "requirement": "180-KTAS cruise at 10,000 ft DA",
                    "target": "Power required <= power available",
                    "analysis_value": (
                        f"{performance['cruise_180kt_10000ft_power_required_hp']:.0f} hp required; "
                        f"{performance['cruise_180kt_10000ft_power_available_hp']:.0f} hp available"
                    ),
                    "status": "PASS" if performance["cruise_180kt_10000ft_pass"] else "FAIL",
                    "note": "Clean parabolic polar; takeoff rating used unless the team supplies a continuous-rating ratio.",
                },
                {
                    "requirement": "Best ROC at 10,000 ft DA",
                    "target": f">= {rfp['minimum_roc_10000ft_fpm']:.0f} ft/min",
                    "analysis_value": f"{performance['best_roc_10000ft_fpm']:.0f} ft/min",
                    "status": "PASS" if performance["roc_10000ft_pass"] else "FAIL",
                    "note": "Preliminary excess-power calculation.",
                },
                {
                    "requirement": "Best ROC at sea level",
                    "target": f">= {rfp['minimum_roc_sea_level_fpm']:.0f} ft/min",
                    "analysis_value": f"{performance['best_roc_0ft_fpm']:.0f} ft/min",
                    "status": "PASS" if performance["roc_sea_level_pass"] else "FAIL",
                    "note": "Preliminary excess-power calculation.",
                },
                {
                    "requirement": "OEI ROC at sea level",
                    "target": f">= {rfp['minimum_oei_roc_sea_level_fpm']:.0f} ft/min",
                    "analysis_value": f"{performance['oei_best_roc_sea_level_fpm']:.0f} ft/min",
                    "status": "PASS" if performance["oei_roc_sea_level_pass"] else "FAIL",
                    "note": "One of two equal engines operative; same best-ROC speed as all-engines case approximation.",
                },
                {
                    "requirement": "Wingspan limit",
                    "target": f"< {requirements['geometry']['span_limit_ft']:.0f} ft",
                    "analysis_value": f"{performance['span_ft']:.1f} ft",
                    "status": "PASS" if performance["span_limit_pass"] else "FAIL",
                    "note": "Uses b = sqrt(AR*S).",
                },
            ]
        )
    else:
        rows.append(
            {
                "requirement": "Flight-performance checks",
                "target": "Cruise, climb, OEI climb, span",
                "analysis_value": "Missing: " + "; ".join(performance["missing_inputs"]),
                "status": "NOT EVALUATED",
                "note": "Supply the three optional inputs to execute these checks.",
            }
        )
    return rows


def write_report(
    path: Path,
    requirements: Dict[str, Any],
    final_weight_lb: float,
    mission: MissionResult,
    aero: TtpaAero,
    performance: Dict[str, Any],
    traceability: List[Dict[str, str]],
    iteration_count: int,
) -> None:
    design_range = requirements["design_range_nmi"]
    payload = requirements["payload"]["W_payload_fixed_lb"]
    lines = [
        "# Tidal Flight mission-analysis summary",
        "",
        "## Source-backed result",
        "",
        f"- Converged takeoff weight: **{final_weight_lb:,.1f} lb** ({iteration_count} iterations)",
        f"- Selected payload: **{payload:,.0f} lb**",
        f"- Design cruise range: **{design_range:,.0f} nmi**",
        f"- Mission fuel burned: **{mission.mission_fuel_lb:,.1f} lb**",
        f"- Additional 6% reserve/trapped fuel: **{mission.reserve_fuel_lb:,.1f} lb**",
        f"- Total carried fuel used in weight closure: **{mission.total_fuel_lb:,.1f} lb**",
        f"- Clean Oswald efficiency: **{aero.e:.4f}**",
        f"- Clean induced-drag factor K: **{aero.K:.5f}**",
        f"- Clean maximum L/D: **{aero.LD_max:.2f}**",
        "",
        "",
        "## Requirement extraction and conflicts resolved",
        "",
        "- The compliance mission uses the RFP range of 1,000 statute miles (868.976 nmi).",
        "- The RFP payload is 9 passengers x (180 lb person + 50 lb baggage) + 2 pilots x 180 lb = 2,430 lb.",
        "- The RFP calls for 45 minutes of IFR reserve energy and a balked landing at the start of reserve. The mission represents this with a climb to 4,000 ft followed by a 45-minute loiter.",
        "- The mission cruise is 130 KTAS at 10,000 ft; the separate capability check is 180 KTAS at 10,000 ft density altitude.",
        "",
        "## Flight-performance status",
        "",
    ]
    if performance.get("status") == "EVALUATED":
        lines.extend(
            [
                f"- Wing area: **{performance['wing_area_ft2']:,.1f} ft^2**",
                f"- Sea-level installed shaft power: **{performance['power_sl_hp']:,.0f} hp**",
                f"- Clean CLmax: **{performance['clmax_clean']:.3f}**",
                f"- Best ROC at 10,000 ft: **{performance['best_roc_10000ft_fpm']:,.0f} ft/min**",
                f"- Best ROC at sea level: **{performance['best_roc_0ft_fpm']:,.0f} ft/min**",
                f"- OEI ROC at sea level: **{performance['oei_best_roc_sea_level_fpm']:,.0f} ft/min**",
            ]
        )
    else:
        lines.append(
            "Flight-performance checks were not evaluated because the supplied files do not contain: "
            + ", ".join(performance["missing_inputs"])
            + "."
        )
    lines.extend(["", "## Traceability", ""])
    for row in traceability:
        lines.append(
            f"- **{row['status']} - {row['requirement']}:** {row['analysis_value']} "
            f"(target: {row['target']}). {row['note']}"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--requirements",
        type=Path,
        default=Path(__file__).with_name("tidal_requirements.json"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).with_name("results"),
    )
    parser.add_argument("--wing-area", type=float, default=None, help="Wing reference area, ft^2")
    parser.add_argument("--power-hp", type=float, default=None, help="Total sea-level takeoff shaft power, hp")
    parser.add_argument("--clmax-clean", type=float, default=None, help="Clean maximum lift coefficient")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    requirements = load_json(args.requirements)
    args.output.mkdir(parents=True, exist_ok=True)

    aero = TtpaAero(str(args.requirements))
    prop = SeaplaneProp(requirements)
    weights = TidalWeights(str(args.requirements))

    wing_area = args.wing_area or requirements["geometry"].get("S_ref_ft2")
    power_hp = args.power_hp or requirements["propulsion"].get("P_SL_hp")
    clmax_clean = args.clmax_clean or requirements["aerodynamics"].get("CLmax_clean")

    final_weight, mission, iterations = size_takeoff_weight(
        requirements, aero, prop, weights
    )
    payload_range = payload_range_rows(
        final_weight, requirements, aero, prop, weights
    )
    performance_rows, performance_summary = performance_analysis(
        final_weight,
        requirements,
        aero,
        prop,
        wing_area,
        power_hp,
        clmax_clean,
    )
    add_climb_time_distance(
    mission.segments,
    performance_summary,
    roc_fraction=1.0,
)
    traceability = requirement_traceability(
        requirements, final_weight, mission, performance_summary
    )

    write_csv(args.output / "mission_segments.csv", mission.segments)
    write_csv(args.output / "sizing_iterations.csv", iterations)
    write_csv(args.output / "payload_range.csv", payload_range)
    write_csv(args.output / "requirements_traceability.csv", traceability)
    if performance_rows:
        write_csv(args.output / "flight_performance.csv", performance_rows)

    plot_payload_range(args.output / "payload_range.png", payload_range, requirements)
    plot_performance(args.output / "flight_performance.png", performance_rows)
    plot_sizing_convergence(args.output / "sizing_convergence.png", iterations)
    (args.output / "performance_summary.json").write_text(
        json.dumps(performance_summary, indent=2) + "\n", encoding="utf-8"
    )
    write_report(
        args.output / "analysis_summary.md",
        requirements,
        final_weight,
        mission,
        aero,
        performance_summary,
        traceability,
        len(iterations),
    )
    print_team_analysis_report(
        final_weight,
        mission,
        iterations,
        weights,
        performance_summary,
        args.output,
    )

if __name__ == "__main__":
    main()
