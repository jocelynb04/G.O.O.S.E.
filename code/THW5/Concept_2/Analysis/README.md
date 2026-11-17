# Main analysis implementation

Only active dependencies of the full study are kept here. MATLAB loads these folders through the root `setup_concept2.m`.

| Folder | Main responsibilities |
|---|---|
| Configuration | Load inputs, validate assumptions, build disciplines and operating contexts |
| Models | Geometry, aerodynamics, propulsion, weights, atmosphere and their base classes |
| Propulsion | Catalog power, assumed turbine maps and source availability |
| Constraints | Aerodynamic demands, landing boundary and source feasibility |
| Mission | Phase schedules, battery SOC, fuel and mission energy sizing |
| Sizing | Candidate-wing/source search, coupled mass closure and sizing utilities |
| Reporting | Comparison metrics, sensitivity labels and source-specific diagrams |
| Utilities | Project/input paths, atmosphere access and structure helpers |

Main flow: `run_concept2_study` -> `build_concept2_study` -> `source_constraint_sizing`; the optional closure loop uses `source_sizing_mainloop`. Each candidate uses the live discipline models and hybrid mission/SOC calculation. Reporting follows the evaluated aircraft. Tests and optional studies are under `Supplemental`.
