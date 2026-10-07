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

SELECTED_DESIGN = {
    "wing_area_ft2": 350.0,
    "aspect_ratio": 8.0,
    "installed_power_hp": 1350.0,
    "maximum_takeoff_weight_lb": 12500.0,
}

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
    current_ws = takeoff_weight_lb / wing_area_ft2
    current_wp = takeoff_weight_lb / power_sl_hp

    # A route-driven weight can exceed the preliminary plotting range.  Expand
    # the sweep automatically so the selected mission is always evaluated.
    ws_min = min(ws_min, 0.90 * current_ws)
    ws_max = max(ws_max, 1.10 * current_ws)
    wing_loading = np.linspace(ws_min, ws_max, points)

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
        fig, ax = plt.subplots(figsize=(12.5, 7.5))

        feasible_mask = wing_loading <= ws_wall
        ax.fill_between(
            wing_loading[feasible_mask],
            0.0,
            envelope[feasible_mask],
            color="#b8efaa",
            alpha=0.55,
            label="Feasible design region",
        )

        colors = ["#7b2cbf", "#1d4ed8", "#16a34a", "#dc2626", "#ca8a04", "#0891b2"]
        for index, (name, curve) in enumerate(power_curves.items()):
            linestyle = "--" if "takeoff" in name.lower() else "-"
            ax.plot(
                wing_loading,
                curve,
                color=colors[index % len(colors)],
                linestyle=linestyle,
                linewidth=2.2,
                label=name,
            )

        for name, wall in wing_loading_walls.items():
            ax.axvline(
                wall,
                color="#374151",
                linestyle="--",
                linewidth=2.0,
                label=name,
            )

        ax.plot(
            current_ws,
            current_wp,
            marker="*",
            linestyle="none",
            color="#f4b400",
            markeredgecolor="black",
            markeredgewidth=1.2,
            markersize=17,
            zorder=8,
            label=f"Selected design ({current_ws:.1f}, {current_wp:.2f})",
        )

        # Show the power-loading margin from the selected point to the
        # controlling constraint at the same wing loading.
        ax.plot(
            [current_ws, current_ws],
            [current_wp, current_limit],
            color="black",
            linestyle=":",
            linewidth=1.4,
            zorder=7,
        )
        ax.plot(current_ws, current_limit, "kx", markersize=7, zorder=8)

        design_text = (
            f"Selected design\n"
            f"W/S = {current_ws:.1f} lb/ft²\n"
            f"W/P = {current_wp:.2f} lb/hp\n"
            f"S = {wing_area_ft2:.0f} ft²,  P = {power_sl_hp:.0f} hp\n"
            f"b = {math.sqrt(float(geometry['AR']) * wing_area_ft2):.1f} ft\n"
            f"Driver: {driving_constraint}"
        )
        ax.annotate(
            design_text,
            xy=(current_ws, current_wp),
            xytext=(current_ws + 4.0, current_wp + 12.0),
            arrowprops={"arrowstyle": "->", "color": "#374151", "lw": 1.4},
            bbox={"boxstyle": "round,pad=0.45", "fc": "white", "ec": "#6b7280", "alpha": 0.95},
            fontsize=9,
            zorder=9,
        )

        ax.set_xlabel(r"Wing loading $W_{TO}/S$ [lb/ft$^2$]")
        ax.set_ylabel(r"Power loading $W_{TO}/P_{SL}$ [lb/hp]")
        ax.set_title("Tidal Flight Mission Constraint Diagram", fontweight="bold")
        ax.set_xlim(ws_min, ws_max)
        ax.set_ylim(bottom=0.0)
        ax.grid(True, alpha=0.25)
        ax.set_axisbelow(True)
        ax.legend(loc="upper right", fontsize=8, framealpha=0.95)
        fig.tight_layout()
        fig.savefig(plot_path, dpi=200)
        plt.close(fig)

    return {
        "current_wing_area_ft2": wing_area_ft2,
        "current_span_ft": math.sqrt(float(geometry["AR"]) * wing_area_ft2),
        "current_installed_power_hp": power_sl_hp,
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
    print(f"Current wing area           = {result['current_wing_area_ft2']:.1f} ft^2")
    print(f"Current wingspan            = {result['current_span_ft']:.1f} ft")
    print(f"Current installed power     = {result['current_installed_power_hp']:.1f} hp")
    print(f"Allowable W/P at current W/S= {result['allowable_power_loading_at_current_ws']:.2f} lb/hp")
    print(f"Driving constraint          = {result['driving_constraint_at_current_ws']}")
    print(f"Current design              = {status}")
    print(f"Preliminary selected W/S    = {result['selected_ws_psf']:.2f} lb/ft^2")
    print(f"Preliminary selected W/P    = {result['selected_wp_lb_per_hp']:.2f} lb/hp")
    print(f"10%-margin reference area   = {result['required_wing_area_ft2']:.1f} ft^2")
    print(f"10%-margin reference span   = {result['required_span_ft']:.1f} ft")
    print(f"10%-margin reference power  = {result['required_power_hp']:.1f} hp")
    if result["plot_path"]:
        print(f"Constraint plot             = {result['plot_path']}")

def load_requirements(json_path: str | Path) -> dict[str, Any]:
    with Path(json_path).open("r", encoding="utf-8") as stream:
        return json.load(stream)


def apply_selected_design(requirements: dict[str, Any]) -> None:
    """Use the geometry and power selected by the mission/constraint trade."""
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

def load_converged_takeoff_weight(sizing_csv: str | Path) -> float:
    """Read the greatest final profile weight from mission-analysis output."""
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

    # The revised mission analysis sizes multiple profiles. Keep only the
    # final iteration of each profile, then use the heavier result.
    final_by_profile: dict[str, float] = {}
    for row in rows:
        profile = row.get("profile", "single mission")
        final_by_profile[profile] = float(row["weight_new_lb"])
    return max(final_by_profile.values())


def load_design_mission(
    mission_summary_csv: str | Path,
) -> tuple[float, str]:
    """Read the profile selected as the aircraft-sizing driver."""
    csv_path = Path(mission_summary_csv)
    if not csv_path.is_file():
        raise FileNotFoundError(csv_path)

    with csv_path.open("r", newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if not rows:
        raise ValueError(f"Mission profile summary is empty: {csv_path}")

    driver_rows = [
        row for row in rows if row.get("design_driver", "").strip().upper() == "YES"
    ]
    driver = driver_rows[0] if driver_rows else max(
        rows, key=lambda row: float(row["takeoff_weight_lb"])
    )
    return float(driver["takeoff_weight_lb"]), driver["profile"]


def evaluate_mission_legs(
    mission_legs_csv: str | Path,
    wing_area_ft2: float,
    power_sl_hp: float,
    requirements: dict[str, Any],
) -> list[dict[str, Any]]:
    """Check every route-leg departure point against the same constraints."""
    csv_path = Path(mission_legs_csv)
    if not csv_path.is_file():
        return []

    with csv_path.open("r", newline="", encoding="utf-8") as stream:
        legs = list(csv.DictReader(stream))

    checks: list[dict[str, Any]] = []
    for leg in legs:
        leg_weight = float(leg["takeoff_weight_lb"])
        result = run_constraint_analysis(
            takeoff_weight_lb=leg_weight,
            wing_area_ft2=wing_area_ft2,
            power_sl_hp=power_sl_hp,
            requirements=requirements,
            make_plot=False,
        )
        checks.append(
            {
                "profile": leg["profile"],
                "leg_number": leg["leg_number"],
                "origin": leg["origin"],
                "destination": leg["destination"],
                "takeoff_weight_lb": leg_weight,
                "wing_loading_psf": result["current_wing_loading_psf"],
                "power_loading_lb_per_hp": result[
                    "current_power_loading_lb_per_hp"
                ],
                "allowable_power_loading_lb_per_hp": result[
                    "allowable_power_loading_at_current_ws"
                ],
                "driving_constraint": result[
                    "driving_constraint_at_current_ws"
                ],
                "feasible": result["current_design_feasible"],
            }
        )
    return checks


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

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
        "--mission-summary",
        type=Path,
        default=None,
        help="mission_profile_summary.csv; defaults to OUTPUT/mission_profile_summary.csv.",
    )
    parser.add_argument(
        "--mission-legs",
        type=Path,
        default=None,
        help="mission_legs.csv; defaults to OUTPUT/mission_legs.csv.",
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
    apply_selected_design(requirements)

    sizing_csv = args.sizing_csv or (args.output / "sizing_iterations.csv")
    mission_summary_csv = args.mission_summary or (
        args.output / "mission_profile_summary.csv"
    )
    mission_legs_csv = args.mission_legs or (args.output / "mission_legs.csv")

    if args.takeoff_weight is not None:
        takeoff_weight_lb = args.takeoff_weight
        driving_profile = "Command-line takeoff-weight override"
    elif mission_summary_csv.is_file():
        takeoff_weight_lb, driving_profile = load_design_mission(
            mission_summary_csv
        )
    else:
        takeoff_weight_lb = load_converged_takeoff_weight(sizing_csv)
        driving_profile = "Heaviest converged mission profile"
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
    result["mission_profile_driver"] = driving_profile
    result["mission_takeoff_weight_lb"] = takeoff_weight_lb
    result["maximum_takeoff_weight_lb"] = float(
        requirements["weights"]["maximum_takeoff_weight_lb"]
    )
    result["mtow_requirement_pass"] = (
        takeoff_weight_lb <= result["maximum_takeoff_weight_lb"]
    )

    leg_checks = evaluate_mission_legs(
        mission_legs_csv=mission_legs_csv,
        wing_area_ft2=wing_area_ft2,
        power_sl_hp=power_sl_hp,
        requirements=requirements,
    )
    if leg_checks:
        route_checks = [
            row
            for row in leg_checks
            if not row["profile"].startswith("RFP nonstop")
        ]
        route_checks = route_checks or leg_checks
        critical_leg = max(
            route_checks, key=lambda row: float(row["takeoff_weight_lb"])
        )
        result["critical_route_leg"] = (
            f"{critical_leg['origin']} to {critical_leg['destination']}"
        )
        result["all_route_legs_feasible"] = all(
            bool(row["feasible"]) for row in route_checks
        )
    args.output.mkdir(parents=True, exist_ok=True)
    summary_path = args.output / "constraint_summary.json"
    summary_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    write_csv(args.output / "mission_leg_constraint_checks.csv", leg_checks)

    print(f"\nMission sizing driver       = {driving_profile}")
    print(f"Mission design weight       = {takeoff_weight_lb:.1f} lb")
    print(
        "MTOW requirement            = "
        + ("PASS" if result["mtow_requirement_pass"] else "FAIL")
        + f" ({result['maximum_takeoff_weight_lb']:.0f} lb maximum)"
    )
    print_constraint_report(result)
    if leg_checks:
        print(
            "All operational route legs  = "
            + ("PASS" if result["all_route_legs_feasible"] else "FAIL")
        )
        print(f"Critical operational leg    = {result['critical_route_leg']}")
        print(
            "Leg-by-leg checks           = "
            f"{args.output / 'mission_leg_constraint_checks.csv'}"
        )
    print(f"Constraint summary          = {summary_path}")

if __name__ == "__main__":
    main()
