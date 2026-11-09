# Concept 4 — MATLAB THW5 Integration

This folder provides MATLAB equivalents of the integrated Python Concept 4 aerodynamic, hydrodynamic, propulsion, weights, mission, constraint, and coupled sizing code, using the IHW3 MATLAB files as methodology references.

## Where to put files

Copy all files from **`matlab/`** into a *new integration branch or folder* of your team's existing repository. Do not replace teammates' original MATLAB classes without review. The `reference_IHW3/` folder contains the original Concept 3/IHW3 MATLAB examples for comparison and should **not** be placed on the working MATLAB path, because it contains files with the same names as the Concept 4 sizing wrappers.

## Run in MATLAB

Open MATLAB, change Current Folder to the `matlab/` directory, and run:

```matlab
test_concept4_integration
run_concept4_smoke
result = run_concept4_sizing;
plot_concept4_results
```

Or specify the complete inputs:

```matlab
result = run_concept4_sizing('concept4_aero_hydro_requirements.json', ...
    'concept4_integration_assumptions.json', 'results');
```

MATLAB writes `results/sizing_results.json`, `sizing_history.csv`, `mission_segments.csv`, `matching_diagram_data.csv`, and `RFP_status.json`. The plotting function generates three `.png` files from the CSV outputs.

The code is written for modern MATLAB releases supporting `classdef`, `jsondecode`, `jsonencode`, `string`, `table`, and `writetable` (recommend R2021b or later).

## What was translated

| Python source / IHW3 step | MATLAB file |
|---|---|
| `SeaplaneGeom.py` + geometry adapter | `SeaplaneGeom.m`, `Concept4GeometryAdapter.m` |
| `SeaplaneAero_Concept4.py` | `SeaplaneAero_Concept4.m` |
| `SeaplaneHydro_Concept4.py` | `SeaplaneHydro_Concept4.m` |
| `SeaplaneProp_Concept4.py` | `SeaplaneProp_Concept4.m` |
| `SeaplaneWeights.py` | `SeaplaneWeights.m` |
| `segment_climb_L2.py` / `.m` | `segment_climb_C4.m` |
| `segment_cruise_L2.py` / `.m` | `segment_cruise_C4.m` |
| `segment_loiter_L2.py` / `.m` | `segment_loiter_C4.m` |
| `constraint_cruise_speed.py` / `.m` | `constraint_cruise_speed_C4.m` |
| `Concept4Constraints.py` | `matching_envelope_C4.m`, `Concept4Constraints.m` |
| `Concept4Mission.py` | `Concept4Mission.m` |
| `Concept4Sizing.py` | `Concept4Sizing.m` |
| `sizing_pass.py` / `.m` | `sizing_pass.m` |
| `sizing_mainloop.py` / `.m` | `sizing_mainloop.m` |
| `Concept4Verification.py` | `Concept4Verification.m` |
| `run_concept4_sizing.py` | `run_concept4_sizing.m` |
| `plot_concept4_results.py` | `plot_concept4_results.m` |
| `test_concept4_integration.py` | `test_concept4_integration.m` |
| atmospheric and utility logic | `isa_atmosphere_C4.m`, `c4_get.m`, `c4_segments.m`, `c4_required_climb_hp.m`, `write_json_C4.m` |

The two original JSON input datasets are reused unchanged. **Do not use the original classroom piston-twin requirements JSON.**

## Scope and limitations

- This is preliminary analysis, not a compliant/certified aircraft design.
- Float water-run hump resistance, actual water takeoff/landing distances, flooding, finite-heel stability, and crosswind dynamics are unverified.
- Stopped-propeller drag and yaw effects during a failed motor are unverified; the OEI power screen is optimistic.
- Electric-only ground and balked-landing mission phases use provisional time/power assumptions.
- Installed propulsion specific power/energy, generator lapse, and BSFC are placeholders, not engine vendor data.
- The team's earlier 12,500-lb gross weight is a preliminary design objective, **not** an RFP or certification limit.
- MATLAB source execution **has not been verified in this environment**, which does not contain a MATLAB runtime. The existing Python reference model was rerun successfully and gave numerical convergence in 56 iterations. The MATLAB translation has undergone static checks and needs an actual MATLAB test run by the team.

## Debug order

1. Run `test_concept4_integration` to validate basic interfaces.
2. Run `run_concept4_smoke` for one sample aircraft.
3. Run `run_concept4_sizing` for the coupled sizing loop.
4. Run `plot_concept4_results` only after CSV results exist.
5. If MATLAB reports a specific line error, compare that `.m` file against the matching Python source or reference MATLAB file.
