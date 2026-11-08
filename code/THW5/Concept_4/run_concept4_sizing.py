import argparse
import csv
import json
from pathlib import Path

from Concept4Sizing import Concept4Sizing
from Concept4Verification import summarize
from Concept4Constraints import matching_envelope
from sizing_mainloop import sizing_mainloop


HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--json",
        type=Path,
        default=HERE / "concept4_aero_hydro_requirements.json"
    )

    parser.add_argument(
        "--assumptions",
        type=Path,
        default=HERE / "concept4_integration_assumptions.json"
    )

    parser.add_argument(
        "--output",
        type=Path,
        default=HERE / "results"
    )

    parser.add_argument("--max-iter", type=int, default=None)
    parser.add_argument("--tol", type=float, default=None)
    parser.add_argument("--relaxation", type=float, default=None)

    args = parser.parse_args()

    with args.json.open("r", encoding="utf-8") as f:
        J = json.load(f)

    with args.assumptions.open("r", encoding="utf-8") as f:
        assumptions = json.load(f)

    solver = Concept4Sizing(J, assumptions)

    result = sizing_mainloop(
        solver,
        max_iter=args.max_iter,
        tol=args.tol,
        relaxation=args.relaxation
    )

    args.output.mkdir(parents=True, exist_ok=True)

    with (args.output / "sizing_results.json").open(
        "w", encoding="utf-8"
    ) as f:
        json.dump(result, f, indent=2, allow_nan=False)

    history = result["history"]

    with (args.output / "sizing_history.csv").open(
        "w", newline="", encoding="utf-8"
    ) as f:
        writer = csv.writer(f)

        writer.writerow([
            "iteration",
            "W_TO_lb",
            "S_ref_ft2",
            "motor_shaft_hp",
            "generator_engine_hp_each",
            "battery_capacity_kwh",
            "OEW_lb",
            "payload_lb",
            "mission_fuel_lb",
            "mission_soc_end",
            "span_ft",
            "max_residual"
        ])

        for row in history:
            x = row["proposed"]

            writer.writerow([
                row["iteration"],
                x["W_TO_lb"],
                x["S_ref_ft2"],
                x["motor_shaft_hp"],
                x["generator_engine_hp_each"],
                x["battery_capacity_kwh"],
                row["OEW_lb"],
                row["payload_lb"],
                row["mission_fuel_lb"],
                row["mission_soc_end"],
                row["span_ft"],
                row["max_residual"]
            ])

    final = result["final"]

    if final:
        segments = final["mission"]["segments"]

        if segments:
            with (args.output / "mission_segments.csv").open(
                "w", newline="", encoding="utf-8"
            ) as f:
                writer = csv.DictWriter(
                    f,
                    fieldnames=list(segments[0].keys())
                )
                writer.writeheader()
                writer.writerows(segments)

    verification = summarize(J, result, solver)

    with (args.output / "RFP_status.json").open(
        "w", encoding="utf-8"
    ) as f:
        json.dump(
            verification,
            f,
            indent=2,
            allow_nan=False
        )

    envelope = matching_envelope(
        J,
        solver.geom,
        solver.aero,
        solver.prop,
        result["state"]["W_TO_lb"],
        assumptions
    )

    candidates = envelope["candidates"]

    if candidates:
        with (args.output / "matching_diagram_data.csv").open(
            "w", newline="", encoding="utf-8"
        ) as f:
            writer = csv.DictWriter(
                f,
                fieldnames=list(candidates[0].keys())
            )
            writer.writeheader()
            writer.writerows(candidates)

    print("STATUS:", result["status"])
    print("ITERATIONS:", result["iterations_completed"])
    print("STATE:", json.dumps(result["state"], indent=2))

    if final:
        print(
            "FINAL MASS CLOSURE RESIDUAL [lb]:",
            final["mass_closure_residual_lb"]
        )

    if result["failure_reason"]:
        print("STOP REASON:", result["failure_reason"])

    print("Outputs:", args.output)


if __name__ == "__main__":
    main()
