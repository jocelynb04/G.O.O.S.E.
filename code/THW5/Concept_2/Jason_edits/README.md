# Concept 2 — Jason edits

This working copy follows the Concept3_Debug_Copy organization. Concept 2's
parallel-hybrid physics, inputs, mission cases and mass accounting are retained.

| Location | Purpose |
|---|---|
| `untitled.m` | Run button entry point, like Concept 3; leaves `analysis` and `hist` in the workspace |
| `matchingdiagram.m` | Runs the study and displays the motor, turbine and combined constraint diagrams |
| `run_concept2_study.m` | Full study with optional mass closure and sensitivity cases |
| `TtpaAero.m`, `TtpaGeom.m`, `TtpaProp.m`, `TtpaWeights.m` | Aircraft-specific discipline models |
| `ttpa_disciplines.m` | Builds the discipline bundle and enables the shared framework |
| `sizing_mainloop.m`, `sizing_pass.m`, `SizingSteps.m` | Mass closure, hybrid source sizing and sizing utilities |
| `hybrid_*.m` | Concept 2 phase schedules, energy and battery SOC calculations |
| Other top-level `.m` files | Concept 2 configuration, propulsion, constraints and reporting |
| `framework/` | Base classes, aircraft state, importers, shared utilities and landing constraint |
| `concept2.json` | Active aircraft requirements, geometry, missions and source configuration |
| `concept2_study_inputs.json` | Operating assumptions, electrical limits and search settings |
| `turbine_engine_catalog.json` | Engine catalog; stays beside `concept2.json` |
| `study_input_register.csv` | Input provenance and validation needs |
| `Results/Current/` | Latest saved reports and constraint diagrams |
| `Before_Structure_*.zip` | Snapshot of the previous code/input layout and baseline numerical result |

Set MATLAB's current folder to this directory and run `untitled`, or:

```matlab
[analysis,hist] = matchingdiagram();
% Optional weight closure:
[result,hist] = run_concept2_study('sizing',true,'plot_visible',true);
```

`source_sizing_mainloop` and `source_constraint_sizing` remain compatibility
entry points for `sizing_mainloop` and `sizing_pass`. The hybrid sizing signatures
and outputs are retained; they differ from Concept 3's conventional power model.
Separate motor and turbine plots remain necessary for the hybrid installation.
Input edits require a new run. Default runs overwrite matching outputs only in
this copy's `Results/Current` folder.

The starting-aircraft study passes mission/constraints at 12,000 lb but estimates
18,856 lb total mass. This is not a mass-closed design; inspect `mass_closed`
before interpreting feasibility. Hardware and certification validation remain open.


## Caravan-style combined hybrid diagram

Run `untitled` or `matchingdiagram` to generate `Results/Current/concept2_matching_diagram.png`
and its vector PDF. The main chart now uses the same normalization as
`Cessna_208/Hybrid_MultiEngine/src/twin_constraint_analysis.m`:

`limit = (W_TO / P_SL_peak) * (source_available_shp / source_required_shp)`.

`P_SL_peak` is Concept 2's net combined sea-level peak shaft power, limited by
its turbine map, motors, pack, inverter, duration, accessories and shared gearbox.
It is a reporting reference with both sources available; electric takeoff and
other turbine-off constraints retain electric-only availability. A yellow star
marks the installed twin reference. A dark-green horizontal line shows wing
loadings that the actual installation supports under all static constraints.

The light-green area is a fixed-ratio scaling reference with the mission-derived
SOC and source assumptions held fixed. It does not establish a resized catalog
engine, battery, mission solution or mass closure. Every Concept 2 power condition
is included in the envelope, with its landing and span boundaries enforced.
The Caravan aircraft assumptions and mission dispatch are not copied into Concept 2.

The original source-specific motor, turbine and margin plots remain available.
`hybrid_constraint_analysis.mat` stores the normalized curves and reference;
`hybrid_reference_power.csv` records required/available power by condition.
