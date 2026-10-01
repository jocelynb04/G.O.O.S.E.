from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

KNOT_TO_FPS = 6076.115 / 3600.0
RHO_SLUG_FT3_SL = 0.0023769

@dataclass(frozen=True)
class Atmosphere:
    altitude_ft: float
    rho_slug_ft3: float
    sigma: float

def isa_state(altitude_ft: float) -> Atmosphere:
    """1976-standard-atmosphere approximation in the troposphere."""
    if not 0.0 <= altitude_ft <= 36089.0:
        raise ValueError("This preliminary ISA model is valid from 0 to 36,089 ft.")

    temperature_r = 518.67 - 0.00356616 * altitude_ft
    pressure_psf = 2116.22 * (temperature_r / 518.67) ** 5.2561
    rho = pressure_psf / (1716.0 * temperature_r)
    return Atmosphere(altitude_ft, rho, rho / RHO_SLUG_FT3_SL)

def _configuration_polar(aero: dict[str, Any], config: str) -> dict[str, float]:
    ar = float(aero["AR"])
    e = float(aero["e_clean"])
    cd0 = float(aero["CD0_clean"])

    if config == "clean":
        clmax = float(aero["CLmax_clean"])
    elif config in {"takeoff_flaps_gear_up", "takeoff_flaps_gear_down"}:
        clmax = float(aero["CLmax_takeoff"])
        cd0 += float(aero.get("delta_CD0_flaps_takeoff", 0.0))
        e += float(aero.get("delta_e_flaps_takeoff", 0.0))
        if config.endswith("gear_down"):
            cd0 += float(aero.get("delta_CD0_gear_down", 0.0))
    elif config in {"landing_flaps_gear_up", "landing_flaps_gear_down"}:
        clmax = float(aero["CLmax_landing"])
        cd0 += float(aero.get("delta_CD0_flaps_landing", 0.0))
        e += float(aero.get("delta_e_flaps_landing", 0.0))
        if config.endswith("gear_down"):
            cd0 += float(aero.get("delta_CD0_gear_down", 0.0))
    else:
        raise ValueError(f"Unknown aerodynamic configuration: {config!r}")

    if e <= 0.0:
        raise ValueError(f"Oswald efficiency must remain positive for {config!r}.")

    return {
        "CD0": cd0,
        "K": 1.0 / (math.pi * ar * e),
        "CLmax": clmax,
    }

def _power_ratio(
    propulsion: dict[str, Any], state: Atmosphere, condition: dict[str, Any]
) -> float:
    """Available condition power divided by rated sea-level takeoff power."""
    exponent = float(propulsion.get("power_lapse_exponent", 1.0))
    ratio = state.sigma**exponent
    ratio *= float(condition.get("power_setting", 1.0))

    if bool(condition.get("max_continuous", False)):
        ratio /= float(propulsion.get("P_TO_over_P_max_continuous", 1.0))

    if bool(condition.get("oei", False)):
        n_engines = int(propulsion["n_engines"])
        if n_engines < 2:
            raise ValueError("An OEI constraint requires at least two engines.")
        ratio *= (n_engines - 1) / n_engines

    return ratio

def _takeoff_limit(
    wing_loading: np.ndarray,
    condition: dict[str, Any],
    aero: dict[str, Any],
) -> np.ndarray:
    state = isa_state(float(condition["altitude_ft"]))
    polar = _configuration_polar(aero, condition["config"])
    distance_ft = float(condition["distance_ft"])

    # 0.009 TOP^2 + 4.9 TOP - distance = 0; keep the positive root.
    top23 = (-4.9 + math.sqrt(4.9**2 + 4.0 * 0.009 * distance_ft)) / (2.0 * 0.009)
    return top23 * state.sigma * polar["CLmax"] / wing_loading

def _landing_wall(condition: dict[str, Any], aero: dict[str, Any]) -> float:
    state = isa_state(float(condition["altitude_ft"]))
    polar = _configuration_polar(aero, condition["config"])
    beta = float(condition.get("beta", 1.0))

    stall_kts = math.sqrt(float(condition["distance_ft"]) / 0.265)
    stall_fps = stall_kts * KNOT_TO_FPS
    ws_at_landing = 0.5 * state.rho_slug_ft3 * stall_fps**2 * polar["CLmax"]
    return ws_at_landing / beta

def _stall_wall(condition: dict[str, Any], aero: dict[str, Any]) -> float:
    state = isa_state(float(condition["altitude_ft"]))
    polar = _configuration_polar(aero, condition.get("config", "clean"))
    beta = float(condition.get("beta", 1.0))
    stall_fps = float(condition["stall_speed_kts"]) * KNOT_TO_FPS
    ws_at_condition = 0.5 * state.rho_slug_ft3 * stall_fps**2 * polar["CLmax"]
    return ws_at_condition / beta

def _climb_gradient(condition: dict[str, Any]) -> float:
    if "G" in condition:
        return float(condition["G"])

    if "roc_fpm" in condition and "speed_ktas" in condition:
        vertical_fps = float(condition["roc_fpm"]) / 60.0
        horizontal_fps = float(condition["speed_ktas"]) * KNOT_TO_FPS
        return vertical_fps / horizontal_fps

    raise KeyError(
        f"Climb condition {condition.get('name', '')!r} must contain either G, "
        "or both roc_fpm and speed_ktas."
    )

def _climb_limit(
    wing_loading: np.ndarray,
    condition: dict[str, Any],
    aero: dict[str, Any],
    propulsion: dict[str, Any],
) -> np.ndarray:
    state = isa_state(float(condition["altitude_ft"]))
    polar = _configuration_polar(aero, condition["config"])

    cd0 = polar["CD0"]
    if bool(condition.get("propeller_stopped", False)):
        cd0 += float(aero.get("delta_CD0_propeller_stopped", 0.0))

    cl = polar["CLmax"] - float(aero.get("CL_stall_margin", 0.2))
    if cl <= 0.0:
        raise ValueError("CLmax minus the climb stall margin must be positive.")

    cd = cd0 + polar["K"] * cl**2
    lift_to_drag = cl / cd
    cgrp = (_climb_gradient(condition) + 1.0 / lift_to_drag) / math.sqrt(cl)

    eta_p = float(condition.get("eta_p", propulsion["eta_p_climb"]))
    beta = float(condition.get("beta", 1.0))
    kp = _power_ratio(propulsion, state, condition)

    return (
        18.97
        * eta_p
        * math.sqrt(state.sigma)
        * kp
        / (cgrp * beta**1.5 * np.sqrt(wing_loading))
    )

def _cruise_limit(
    wing_loading: np.ndarray,
    condition: dict[str, Any],
    aero: dict[str, Any],
    propulsion: dict[str, Any],
) -> np.ndarray:
    """Direct cruise constraint from drag and required shaft power."""
    state = isa_state(float(condition["altitude_ft"]))
    polar = _configuration_polar(aero, condition.get("config", "clean"))

    speed_fps = float(condition["ktas"]) * KNOT_TO_FPS
    q_psf = 0.5 * state.rho_slug_ft3 * speed_fps**2
    beta = float(condition.get("beta", 1.0))
    eta_p = float(condition.get("eta_p", propulsion["eta_p_cruise"]))
    kp = _power_ratio(propulsion, state, condition)

    # D/W_TO = parasite contribution + induced contribution.
    drag_over_takeoff_weight = (
        q_psf * polar["CD0"] / wing_loading
        + polar["K"] * beta**2 * wing_loading / q_psf
    )

    shaft_hp_per_lb = drag_over_takeoff_weight * speed_fps / (eta_p * 550.0)
    return kp / shaft_hp_per_lb

def run_constraint_analysis(
    takeoff_weight_lb: float,
    wing_area_ft2: float,
    power_sl_hp: float,
    requirements: dict[str, Any],
    output_dir: str | Path = "results",
    make_plot: bool = True,
) -> dict[str, Any]:
    """Evaluate the current airplane and produce a W/S versus W/P diagram."""
    if min(takeoff_weight_lb, wing_area_ft2, power_sl_hp) <= 0.0:
        raise ValueError("Weight, wing area, and sea-level power must be positive.")

    constraint_data = requirements["constraints"]
    geometry = requirements["geometry"]
    aero = dict(requirements["aerodynamics"])
    propulsion = requirements["propulsion"]
    aero["AR"] = float(geometry["AR"])

    ws_min, ws_max = map(float, constraint_data["wing_loading_range_psf"])
    points = int(constraint_data.get("wing_loading_points", 400))
    margin = float(constraint_data.get("design_margin_fraction", 0.10))
    wing_loading = np.linspace(ws_min, ws_max, points)

    current_ws = takeoff_weight_lb / wing_area_ft2
    current_wp = takeoff_weight_lb / power_sl_hp
    if not ws_min <= current_ws <= ws_max:
        raise ValueError(
            f"Current W/S={current_ws:.2f} is outside the constraint sweep "
            f"[{ws_min:.2f}, {ws_max:.2f}]. Expand wing_loading_range_psf."
        )

    power_curves: dict[str, np.ndarray] = {}
    wing_loading_walls: dict[str, float] = {}

    for condition in constraint_data["conditions"]:
        name = str(condition["name"])
        condition_type = condition["type"]

        if condition_type == "takeoff":
            power_curves[name] = _takeoff_limit(wing_loading, condition, aero)
        elif condition_type == "stall_speed":
            wing_loading_walls[name] = _stall_wall(condition, aero)
        elif condition_type == "landing":
            wing_loading_walls[name] = _landing_wall(condition, aero)
        elif condition_type == "climb_gradient":
            power_curves[name] = _climb_limit(
                wing_loading, condition, aero, propulsion
            )
        elif condition_type == "cruise_speed":
            power_curves[name] = _cruise_limit(
                wing_loading, condition, aero, propulsion
            )
        else:
            raise ValueError(f"Unsupported constraint type: {condition_type!r}")

    if not power_curves:
        raise ValueError("At least one power-loading constraint is required.")

    curve_names = list(power_curves)
    curve_matrix = np.vstack([power_curves[name] for name in curve_names])
    envelope = np.min(curve_matrix, axis=0)
    controlling_indices = np.argmin(curve_matrix, axis=0)
    ws_wall = min(wing_loading_walls.values(), default=math.inf)

    current_limit = float(np.interp(current_ws, wing_loading, envelope))
    current_index = int(np.argmin(np.abs(wing_loading - current_ws)))
    driving_constraint = curve_names[int(controlling_indices[current_index])]
    power_margin = (current_limit - current_wp) / current_limit
    wing_margin = (
        math.inf if math.isinf(ws_wall) else (ws_wall - current_ws) / ws_wall
    )
    feasible = current_wp <= current_limit and current_ws <= ws_wall

    usable = np.where(wing_loading <= ws_wall, envelope, -np.inf)
    corner_index = int(np.argmax(usable))
    if not np.isfinite(usable[corner_index]):
        raise ValueError("The selected W/S sweep contains no feasible wing loading.")

    corner_ws = float(wing_loading[corner_index])
    corner_wp = float(envelope[corner_index])

    # Move inside the feasible region rather than selecting the exact corner.
    selected_ws = corner_ws * (1.0 - margin)
    selected_wp_limit = float(np.interp(selected_ws, wing_loading, envelope))
    selected_wp = selected_wp_limit * (1.0 - margin)

    required_area = takeoff_weight_lb / selected_ws
    required_power = takeoff_weight_lb / selected_wp
    required_span = math.sqrt(float(geometry["AR"]) * required_area)

    output_path = Path(output_dir)
    plot_path = output_path / "constraint_diagram.png"

    if make_plot:
        import matplotlib.pyplot as plt

        output_path.mkdir(parents=True, exist_ok=True)
        fig, ax = plt.subplots(figsize=(10, 7))

        feasible_mask = wing_loading <= ws_wall
        ax.fill_between(
            wing_loading[feasible_mask],
            0.0,
            envelope[feasible_mask],
            color="tab:green",
            alpha=0.18,
            label="Feasible region",
        )

        for name, curve in power_curves.items():
            ax.plot(wing_loading, curve, linewidth=2.0, label=name)

        for name, wall in wing_loading_walls.items():
            ax.axvline(wall, linestyle="--", linewidth=2.0, label=name)

        ax.plot(
            current_ws,
            current_wp,
            "ko",
            markersize=8,
            label=f"Current design ({current_ws:.1f}, {current_wp:.2f})",
        )
        ax.plot(
            selected_ws,
            selected_wp,
            marker="*",
            color="gold",
            markeredgecolor="black",
            markersize=15,
            label=f"Preliminary selection ({selected_ws:.1f}, {selected_wp:.2f})",
        )

        ax.set_xlabel(r"Wing loading $W_{TO}/S$ [lb/ft$^2$]")
        ax.set_ylabel(r"Power loading $W_{TO}/P_{SL}$ [lb/hp]")
        ax.set_title("Tidal Flight Constraint Diagram")
        ax.set_xlim(ws_min, ws_max)
        ax.set_ylim(bottom=0.0)
        ax.grid(True, alpha=0.3)
        ax.legend(loc="best", fontsize=8)
        fig.tight_layout()
        fig.savefig(plot_path, dpi=200)
        plt.close(fig)

    return {
        "current_wing_loading_psf": current_ws,
        "current_power_loading_lb_per_hp": current_wp,
        "allowable_power_loading_at_current_ws": current_limit,
        "driving_constraint_at_current_ws": driving_constraint,
        "power_loading_margin_fraction": power_margin,
        "wing_loading_margin_fraction": wing_margin,
        "current_design_feasible": bool(feasible),
        "constraint_corner_ws_psf": corner_ws,
        "constraint_corner_wp_lb_per_hp": corner_wp,
        "selected_ws_psf": selected_ws,
        "selected_wp_lb_per_hp": selected_wp,
        "required_wing_area_ft2": required_area,
        "required_span_ft": required_span,
        "required_power_hp": required_power,
        "plot_path": str(plot_path) if make_plot else None,
    }

def print_constraint_report(result: dict[str, Any]) -> None:
    status = "PASS" if result["current_design_feasible"] else "FAIL"
    print("\nCONSTRAINT ANALYSIS")
    print("-------------------")
    print(f"Current W/S                 = {result['current_wing_loading_psf']:.2f} lb/ft^2")
    print(f"Current W/P                 = {result['current_power_loading_lb_per_hp']:.2f} lb/hp")
    print(f"Allowable W/P at current W/S= {result['allowable_power_loading_at_current_ws']:.2f} lb/hp")
    print(f"Driving constraint          = {result['driving_constraint_at_current_ws']}")
    print(f"Current design              = {status}")
    print(f"Preliminary selected W/S    = {result['selected_ws_psf']:.2f} lb/ft^2")
    print(f"Preliminary selected W/P    = {result['selected_wp_lb_per_hp']:.2f} lb/hp")
    print(f"Required wing area          = {result['required_wing_area_ft2']:.1f} ft^2")
    print(f"Required span               = {result['required_span_ft']:.1f} ft")
    print(f"Required installed power    = {result['required_power_hp']:.1f} hp")
    if result["plot_path"]:
        print(f"Constraint plot             = {result['plot_path']}")

def load_requirements(json_path: str | Path) -> dict[str, Any]:
    with Path(json_path).open("r", encoding="utf-8") as stream:
        return json.load(stream)

def load_converged_takeoff_weight(sizing_csv: str | Path) -> float:
    """Read the final converged takeoff weight from mission-analysis output."""
    csv_path = Path(sizing_csv)
    if not csv_path.is_file():
        raise FileNotFoundError(
            f"Mission sizing output was not found: {csv_path}\n"
            "Run mission_analysis.py first, or supply --takeoff-weight."
        )

    with csv_path.open("r", newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if not rows or "weight_new_lb" not in rows[-1]:
        raise ValueError(
            f"{csv_path} does not contain the expected weight_new_lb column."
        )
    return float(rows[-1]["weight_new_lb"])

def parse_args() -> argparse.Namespace:
    project_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Run the Tidal Flight preliminary constraint analysis."
    )
    parser.add_argument(
        "--requirements",
        type=Path,
        default=project_dir / "tidal_requirements.json",
        help="Shared mission/constraint JSON file.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=project_dir / "results",
        help="Folder for the constraint diagram and summary.",
    )
    parser.add_argument(
        "--sizing-csv",
        type=Path,
        default=None,
        help="Mission sizing_iterations.csv; defaults to OUTPUT/sizing_iterations.csv.",
    )
    parser.add_argument(
        "--takeoff-weight",
        type=float,
        default=None,
        help="Optional takeoff weight override, lb.",
    )
    parser.add_argument("--wing-area", type=float, default=None, help="Wing area, ft^2.")
    parser.add_argument("--power-hp", type=float, default=None, help="Sea-level power, hp.")
    parser.add_argument("--no-plot", action="store_true", help="Skip the PNG plot.")
    return parser.parse_args()

def main() -> None:
    args = parse_args()
    requirements = load_requirements(args.requirements)

    sizing_csv = args.sizing_csv or (args.output / "sizing_iterations.csv")
    takeoff_weight_lb = (
        args.takeoff_weight
        if args.takeoff_weight is not None
        else load_converged_takeoff_weight(sizing_csv)
    )
    wing_area_ft2 = (
        args.wing_area
        if args.wing_area is not None
        else float(requirements["geometry"]["S_ref_ft2"])
    )
    power_sl_hp = (
        args.power_hp
        if args.power_hp is not None
        else float(requirements["propulsion"]["P_SL_hp"])
    )

    result = run_constraint_analysis(
        takeoff_weight_lb=takeoff_weight_lb,
        wing_area_ft2=wing_area_ft2,
        power_sl_hp=power_sl_hp,
        requirements=requirements,
        output_dir=args.output,
        make_plot=not args.no_plot,
    )
    args.output.mkdir(parents=True, exist_ok=True)
    summary_path = args.output / "constraint_summary.json"
    summary_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    print_constraint_report(result)
    print(f"Constraint summary          = {summary_path}")

if __name__ == "__main__":
    main()
