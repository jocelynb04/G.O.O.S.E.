
import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt


def read_csv(path):
    with path.open("r", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def plot_sizing_convergence(folder):
    path = folder / "sizing_history.csv"

    if not path.exists():
        print(f"Missing: {path}")
        return

    rows = read_csv(path)

    if not rows:
        return

    iteration = [int(r["iteration"]) for r in rows]
    weight = [float(r["W_TO_lb"]) for r in rows]

    fig, ax = plt.subplots(figsize=(9, 5))

    ax.plot(
        iteration,
        weight,
        marker="o",
        markersize=3,
        label="Takeoff gross weight"
    )

    ax.set_xlabel("Sizing iteration")
    ax.set_ylabel("Takeoff gross weight (lb)")
    ax.set_title("Concept 4 Sizing Convergence")
    ax.grid(True)
    ax.legend()

    fig.tight_layout()
    fig.savefig(
        folder / "sizing_weight_convergence.png",
        dpi=300
    )
    plt.close(fig)


def plot_mission_soc(folder):
    path = folder / "mission_segments.csv"

    if not path.exists():
        print(f"Missing: {path}")
        return

    rows = read_csv(path)

    if not rows:
        return

    time = [0.0]
    soc = [100.0 * float(rows[0]["soc_start"])]

    elapsed = 0.0

    for row in rows:
        elapsed += float(row["duration_min"])
        time.append(elapsed)
        soc.append(100.0 * float(row["soc_end"]))

    fig, ax = plt.subplots(figsize=(9, 5))

    ax.plot(
        time,
        soc,
        marker="o",
        markersize=3
    )

    ax.set_xlabel("Mission elapsed time (min)")
    ax.set_ylabel("Battery state of charge (%)")
    ax.set_title("Concept 4 Mission Battery SOC")
    ax.set_ylim(0, 100)
    ax.grid(True)

    fig.tight_layout()
    fig.savefig(
        folder / "mission_soc.png",
        dpi=300
    )
    plt.close(fig)


def plot_matching_diagram(folder):
    path = folder / "matching_diagram_data.csv"

    if not path.exists():
        print(f"Missing: {path}")
        return

    rows = read_csv(path)

    if not rows:
        return

    rows.sort(key=lambda r: float(r["wing_loading_psf"]))

    ws = [float(r["wing_loading_psf"]) for r in rows]

    curves = {
        "2000 fpm climb at sea level": "roc_2000_sl_hp",
        "500 fpm climb at 10000 ft": "roc_500_10k_hp",
        "450 fpm OEI preliminary": "roc_450_oei_hp_NO_FAILURE_DRAG",
        "180 KTAS cruise": "cruise_180_hp",
        "Required installed motor rating": "required_motor_hp"
    }

    fig, ax = plt.subplots(figsize=(10, 6))

    for label, key in curves.items():
        if key not in rows[0]:
            continue

        values = [float(r[key]) for r in rows]

        ax.plot(
            ws,
            values,
            label=label
        )

    ax.set_xlabel("Wing loading W/S (lb/ft²)")
    ax.set_ylabel("Motor shaft power (hp)")
    ax.set_title("Concept 4 Preliminary Constraint Analysis")
    ax.grid(True)
    ax.legend()

    fig.tight_layout()
    fig.savefig(
        folder / "matching_power_sweep.png",
        dpi=300
    )
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--results",
        type=Path,
        default=Path(__file__).resolve().parent / "results"
    )

    args = parser.parse_args()
    folder = args.results

    if not folder.exists():
        raise FileNotFoundError(
            f"Results folder does not exist: {folder}"
        )

    plot_sizing_convergence(folder)
    plot_mission_soc(folder)
    plot_matching_diagram(folder)

    print("Concept 4 plotting completed.")
    print(f"Output folder: {folder}")


if __name__ == "__main__":
    main()