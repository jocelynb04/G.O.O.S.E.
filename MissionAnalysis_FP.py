"""
mission_analysis.py

Flight Performance / Mission Analysis
"""

import json
import math
from pathlib import Path

from Weights import TidalWeights
from ttpa_aero import TtpaAero
from seaplane_prop import SeaplaneProp


# ANALYSIS SETTINGS
W_TO_GUESS = 12000.0       # lb
TOL = 1.0                  # lb
MAX_ITER = 30

# Temporary until constraint analysis provides installed power
P_SL_HP = 1000.0

# Optional extra fuel margin
FUEL_RESERVE_FRACTION = 0.05

# MISSION DEFINITION
MISSION = [
    {
        "name": "Takeoff",
        "type": "takeoff",
        "config": "takeoff_flaps_gear_down",
        "altitude_ft": 0.0,
        "speed_kts": 80.0,
        "time_hr": 2.0 / 60.0,
        "power_fraction": 1.0
    },

    {
        "name": "Climb",
        "type": "climb",
        "config": "takeoff_flaps_gear_up",
        "altitude_ft": 5000.0,
        "speed_kts": 120.0,
        "time_hr": 10.0 / 60.0
    },

    {
        "name": "Cruise",
        "type": "cruise",
        "config": "clean",
        "altitude_ft": 10000.0,
        "speed_kts": 180.0,
        "distance_nm": 500.0
    },

    {
        "name": "Loiter",
        "type": "loiter",
        "config": "clean",
        "altitude_ft": 3000.0,
        "speed_kts": 110.0,
        "time_hr": 0.5
    },

    {
        "name": "Landing",
        "type": "landing",
        "config": "landing_flaps_gear_down",
        "altitude_ft": 0.0,
        "speed_kts": 70.0,
        "time_hr": 3.0 / 60.0,
        "power_fraction": 0.35
    }
]

# ATMOSPHERE
def sigma_at_altitude(altitude_ft):
    """
    Preliminary standard-atmosphere density ratio.
    """
    theta = 1.0 - 6.87535e-6 * altitude_ft

    if theta <= 0:
        raise ValueError("Altitude outside valid range.")

    return theta ** 4.2561

def make_state(altitude_ft):
    return {
        "altitude_ft": altitude_ft,
        "sigma": sigma_at_altitude(altitude_ft)
    }

# FLIGHT CONDITION
def get_aero_condition(W_lb, S_ft2, aero, segment):
    """
    Compute aerodynamic condition using aero model.
    """
    state = make_state(segment["altitude_ft"])

    polar = aero.get_config_polar(
        state,
        {"config": segment["config"]}
    )

    rho = 0.0023769 * state["sigma"]

    V_fts = segment["speed_kts"] * 1.68781

    q = 0.5 * rho * V_fts**2

    CL = W_lb / (q * S_ft2)

    CD = (
        polar["CD0"]
        + polar["K1"] * CL**2
        + polar.get("K2", 0.0) * CL
    )

    D_lb = q * S_ft2 * CD

    return {
        "state": state,
        "V_fts": V_fts,
        "CL": CL,
        "CD": CD,
        "D_lb": D_lb,
        "LD": CL / CD
    }

# Variable POWERED SEGMENT
def run_powered_segment(W_in, S_ft2, aero, prop, segment):
    """
    Runs cruise, climb, and loiter using the aero and
    propulsion models.
    """
    aero_cond = get_aero_condition(
        W_in,
        S_ft2,
        aero,
        segment
    )

    state = aero_cond["state"]

    miss_seg = {
        "type": segment["type"]
    }

    # Segment duration
    if "distance_nm" in segment:
        time_hr = (
            segment["distance_nm"]
            / segment["speed_kts"]
        )
    else:
        time_hr = segment["time_hr"]

    # Propulsive power required
    P_prop_hp = (
        aero_cond["D_lb"]
        * aero_cond["V_fts"]
        / 550.0
    )

    # Add climb power if segment is climb
    if segment["type"] == "climb":

        # Using altitude / time to estimate climb rate
        ROC_fpm = (
            segment["altitude_ft"]
            / (time_hr * 60.0)
        )

        ROC_fts = ROC_fpm / 60.0

        P_prop_hp += (
            W_in * ROC_fts / 550.0
        )


    # Shaft power
    eta_p = prop.prop_eff(
        state,
        miss_seg
    )

    P_shaft_hp = P_prop_hp / eta_p

    # Fuel
    fuel_lb = (
        prop.c_bhp(
            state,
            miss_seg
        )
        * P_shaft_hp
        * time_hr
    )

    # Battery
    phi = prop.get_phi(miss_seg)

    battery_Wh = (
        prop.battery_Wh_per_hphr(phi)
        * P_shaft_hp
        * time_hr
    )

    W_out = W_in - fuel_lb

    return {
        "W_out": W_out,
        "fuel_lb": fuel_lb,
        "battery_Wh": battery_Wh,
        "time_hr": time_hr,
        "P_shaft_hp": P_shaft_hp,
        "phi": phi,
        "CL": aero_cond["CL"],
        "CD": aero_cond["CD"],
        "LD": aero_cond["LD"]
    }


# TAKEOFF / LANDING
def run_fixed_power_segment(W_in, prop, segment):
    """
    Simple takeoff/landing energy accounting.
    """
    state = make_state(
        segment["altitude_ft"]
    )

    miss_seg = {
        "type": segment["type"]
    }

    P_shaft_hp = (
        prop.P_SL
        * segment["power_fraction"]
    )

    time_hr = segment["time_hr"]

    fuel_lb = (
        prop.c_bhp(
            state,
            miss_seg
        )
        * P_shaft_hp
        * time_hr
    )

    phi = prop.get_phi(
        miss_seg
    )

    battery_Wh = (
        prop.battery_Wh_per_hphr(phi)
        * P_shaft_hp
        * time_hr
    )

    return {
        "W_out": W_in - fuel_lb,
        "fuel_lb": fuel_lb,
        "battery_Wh": battery_Wh,
        "time_hr": time_hr,
        "P_shaft_hp": P_shaft_hp,
        "phi": phi
    }

# COMPLETE MISSION
def run_mission(W_TO, S_ft2, aero, prop):
    """
    Runs complete mission.

    Tracks:
        fuel burn
        battery discharge/recharge
        aircraft weight
    """

    W = W_TO

    total_fuel = 0.0

    battery_deficit_Wh = 0.0

    peak_battery_deficit_Wh = 0.0

    rows = []


    for segment in MISSION:

        if segment["type"] in (
            "takeoff",
            "landing"
        ):

            result = run_fixed_power_segment(
                W,
                prop,
                segment
            )

        else:

            result = run_powered_segment(
                W,
                S_ft2,
                aero,
                prop,
                segment
            )

        # Battery accounting
        # positive battery energy = discharge
        # negative battery energy = recharge

        battery_deficit_Wh = max(
            0.0,
            battery_deficit_Wh
            + result["battery_Wh"]
        )

        peak_battery_deficit_Wh = max(
            peak_battery_deficit_Wh,
            battery_deficit_Wh
        )


        rows.append({
            "segment": segment["name"],
            "W_in_lb": W,
            "W_out_lb": result["W_out"],
            "fuel_lb": result["fuel_lb"],
            "battery_Wh": result["battery_Wh"],
            "P_shaft_hp": result["P_shaft_hp"],
            "phi": result["phi"],
            "time_hr": result["time_hr"]
        })


        total_fuel += result["fuel_lb"]

        W = result["W_out"]

    return {
        "rows": rows,
        "fuel_lb": total_fuel,
        "battery_required_Wh":
            peak_battery_deficit_Wh,
        "final_weight_lb": W
    }

# SIZING LOOP
def size_aircraft(weights, aero, prop, S_ft2):
    """
    Iterate takeoff weight until:

        WTO =
        OEW
        + payload
        + fuel
        + battery
    """

    W_TO = W_TO_GUESS

    history = []

    for iteration in range(
        1,
        MAX_ITER + 1
    ):
        # OEW

        W_OEW = weights.OEW(
            W_TO
        )

        # Mission
        mission = run_mission(
            W_TO,
            S_ft2,
            aero,
            prop
        )

        # Fuel loaded
        W_fuel = (
            mission["fuel_lb"]
            * (
                1.0
                + FUEL_RESERVE_FRACTION
            )
        )

        # Battery pack
        W_battery = (
            prop.battery_weight(
                mission[
                    "battery_required_Wh"
                ]
            )
        )

        # Energy-system weight
        W_energy = (
            W_fuel
            + W_battery
        )

        weights.W_energy = W_energy

        # New takeoff weight
        W_TO_new = (

            W_OEW

            + weights.W_payload_fixed

            + weights.W_payload_expendable

            + W_energy
        )


        error = (
            W_TO_new
            - W_TO
        )

        history.append({
            "iteration": iteration,
            "W_TO": W_TO,
            "OEW": W_OEW,
            "fuel": W_fuel,
            "battery": W_battery,
            "W_TO_new": W_TO_new,
            "error": error
        })

        print(
            f"Iteration {iteration:2d}: "
            f"WTO = {W_TO:8.1f} lb   "
            f"new WTO = {W_TO_new:8.1f} lb   "
            f"error = {error:7.2f} lb"
        )

        if abs(error) < TOL:

            W_TO = W_TO_new

            break


        W_TO = W_TO_new


    # Final mission at converged weight
    final_mission = run_mission(
        W_TO,
        S_ft2,
        aero,
        prop
    )

    return {
        "W_TO": W_TO,
        "OEW": weights.OEW(W_TO),
        "fuel_lb":
            final_mission["fuel_lb"],
        "battery_Wh":
            final_mission[
                "battery_required_Wh"
            ],
        "battery_lb":
            prop.battery_weight(
                final_mission[
                    "battery_required_Wh"
                ]
            ),
        "mission":
            final_mission,
        "history":
            history
    }

# MAIN
if __name__ == "__main__":

    # File locations
    CODE_DIR = Path(__file__).resolve().parent
    ROOT_DIR = CODE_DIR.parent

    JSON_PATH = (
        ROOT_DIR
        / "aircraft_data.json"
    )
    # Load JSON
    with open(
        JSON_PATH,
        "r",
        encoding="utf-8"
    ) as f:

        J = json.load(f)

    # Instantiate team models
    weights = TidalWeights(
        str(JSON_PATH)
    )

    aero = TtpaAero(
        str(JSON_PATH)
    )

    prop = SeaplaneProp(
        J
    )

    # Installed shaft power
    # Temporary until constraint analysis sets this.
    prop.P_SL = P_SL_HP

    # Wing area
    # Change "S" if your JSON uses another key.
    S_ft2 = (
        J["geometry"]["S"]
    )

    # Run sizing
    results = size_aircraft(
        weights,
        aero,
        prop,
        S_ft2
    )

    # FINAL RESULTS
    print()
    print("=" * 55)
    print("FINAL AIRCRAFT RESULTS")
    print("=" * 55)

    print(
        f"WTO              = "
        f"{results['W_TO']:.1f} lb"
    )

    print(
        f"OEW              = "
        f"{results['OEW']:.1f} lb"
    )

    print(
        f"Mission fuel     = "
        f"{results['fuel_lb']:.1f} lb"
    )

    print(
        f"Battery energy   = "
        f"{results['battery_Wh']/1000:.1f} kWh"
    )

    print(
        f"Battery weight   = "
        f"{results['battery_lb']:.1f} lb"
    )

    print(
        f"Final mission wt = "
        f"{results['mission']['final_weight_lb']:.1f} lb"
    )

    # MISSION BREAKDOWN
    print()
    print("=" * 55)
    print("MISSION SEGMENTS")
    print("=" * 55)

    for row in results["mission"]["rows"]:

        print(
            f"{row['segment']:10s}  "
            f"W: {row['W_in_lb']:8.1f}"
            f" -> {row['W_out_lb']:8.1f} lb   "
            f"Fuel: {row['fuel_lb']:7.2f} lb   "
            f"Battery: {row['battery_Wh']/1000:7.2f} kWh   "
            f"P: {row['P_shaft_hp']:7.1f} hp"
        )