# Grand Caravan EX Amphibian - original standalone MATLAB model

This repository contains the conventional single-engine Cessna Grand Caravan EX Amphibian model from the user's rev0 package. It includes floats through approximate weight/drag effects. It is the original PT6 model; the hybrid and AMP-H570 projects are separate.

## Run the mission profile

Use MATLAB Desktop R2025a (the tested release). Extract/clone this repository and select its root folder as Current Folder. Restart MATLAB first if another version of these same class names has already been loaded. Enter:

```matlab
result = run_profile;
```

The command sets up the project path automatically and prints fuel burn and weight fraction for each mission segment. It returns `result.fuel_lb`, `fuel_fraction`, `burn`, `weight`, `wf`, `detail`, `empty_lb`, `payload_lb`, `mass_margin_lb`, `tank_margin_lb`, and `segment_table`. Use `result` (singular), which is the variable assigned above. To redisplay the readable table, enter `result.segment_table`.

For the original combined benchmark/mission/constraint calculation:

```matlab
result = run_caravan;
```

For exploratory sizing and for verification:

```matlab
sized = run_caravan(true);
verify_project
```

Only MATLAB is required; no Aerospace Toolbox or external framework installation is needed. `verify_project` runs the tests, scans MATLAB syntax, audits required products and writes its report and saved results to `outputs/`. The default mission is L2, with a 500-nmi cruise at 150 KTAS/8000 ft, 800-lb payload including crew, and a 45-minute reserve loiter. Expected reference mission fuel is approximately 1550.3 lb, subject to changes in the active JSON.

## Repository organization

```text
GrandCaravanEX_Amphibian_GitHub/
  README.md                  this guide, including every MATLAB file
  setup_project.m            project-local MATLAB paths
  run_profile.m              mission-only entrypoint
  run_caravan.m              original combined entrypoint
  verify_project.m           tests and verification
  config/                    active aircraft/mission/constraint JSON
  src/
    models/                  propulsion, geometry, aero, weights
    framework/               base classes, atmosphere, discipline factory
    io/                      JSON readers, validation, field adapters
    mission/                 mission dispatch and segment calculations
    constraints/             performance curves and matching envelope
    sizing/                  iterative aircraft resizing
    reference/               aircraft constants and benchmark checks
    analysis/                optional tank-volume and gear-load checks
  tests/                     original tests plus repository-layout tests
  examples/legacy/           inherited verbose course sizing driver
  docs/
    archive/                 old inputs and historical documentation
    provenance/              package checks, old hashes, relocation manifest
    verification/            reviewed verification record
  outputs/                   generated files; ignored by Git
  .gitignore                 output/editor exclusions
  .gitattributes             text and binary file handling
```

`setup_project` adds only the root and known `src` folders. It does not add archived code recursively. After setup, helpers can be called from any Current Folder because the active input path is resolved relative to the checkout. To work directly with helpers, run `setup_project` first.

The active input is **config/GrandCaravanEX_requirements_IHW3.json**. The archived **docs/archive/Original_IHW3.json** is the old course input and is not read during normal execution. The user's rev0 change to the initial climb constraint, `G = 0.0524078` (approximately tan(3 degrees)), is preserved. It requires a minimum climb capability; it does not force the mission climb trajectory to follow exactly 3 degrees or add a 3-degree descent model.

## Which files do I actually need?

For GitHub, keep the organized source, active config, tests and docs. They make the work understandable and reproducible even when some functions are optional at run time. You can omit generated simulation results without preventing execution.

| Item | Needed for `run_profile`? | Recommendation |
|---|---|---|
| Root `run_profile.m` and `setup_project.m` | Yes | Keep |
| `src/models`, `src/framework`, `src/io` | Yes as a group | Keep all; do not delete base classes/readers because they do not run directly |
| `src/mission` L2 files and `mission_fuel.m` | Yes | Keep |
| `src/reference/grand_caravan_ex_params.m` | Yes | Keep; contains constants used by models |
| Active JSON in `config/` | Yes | Keep |
| `run_caravan.m`, constraint calculations, benchmark/check helpers | No for mission-only; yes for the combined runner | Keep as the original analysis capability |
| `src/sizing/` | No for reference mission; yes for `run_caravan(true)` and sizing tests | Keep if documenting or testing sizing |
| `src/mission/run_mission.m` | No for the selected L2 profile; yes for L1 mode | Keep the optional L1 implementation |
| `src/analysis/` | No | Optional; not a validated amphibian structural analysis |
| `examples/legacy/` | No | Optional; archived course example outside default path |
| `tests/` and root `verify_project.m` | No for ordinary mission execution | Keep in GitHub so others can verify the project |
| `docs/` and this README | No | Keep for explanation, assumptions and provenance |
| Original `verification_results.mat` and freshly generated `outputs/` files | No | Do not upload generated files; regenerate locally |
| Archived original JSON / historical package-check JSON | No | Historical evidence only; not active inputs |

The factory still imports the constraint JSON even in mission-only mode, so keep `ConstraintSetImporter.m` and the constraints block in the active config. Constraint calculation functions themselves are not evaluated by `run_profile`. Do not prune files and then expect the full verifier or sizing entrypoint to keep working: those commands intentionally exercise additional capabilities.

## What every MATLAB file means

The labels below distinguish the active mission path from other capabilities. **Mission** means part of the supported profile runtime, **Combined** means used by the original benchmark/envelope runner, **Sizing** means needed for optional resizing, and the other labels indicate optional analysis, legacy code or tests. This is a catalog of functions/classes, not a list of files to run one by one. Call the entrypoint and it calls its helpers in the correct order.

| File | Use | Purpose |
|---|---|---|
| [run_ttpa_sizing_mainloop.m](examples/legacy/run_ttpa_sizing_mainloop.m) | Legacy example | Large inherited course driver with detailed traces, L1/L2 and constraint-method comparisons, plots and post-sizing checks. Kept outside the default path; not validated as a Caravan-specific reporting workflow. |
| [run_caravan.m](run_caravan.m) | Combined | Original entrypoint: benchmark checks, reference mission, margins and constraint envelope. Passing true additionally runs exploratory sizing. |
| [run_profile.m](run_profile.m) | Mission | Simplest entrypoint: runs the reference aircraft mission, prints a segment table and returns fuel, weights, weight fractions and margins. It does not evaluate a constraint envelope or resize the aircraft. |
| [setup_project.m](setup_project.m) | Setup | Adds this checkout and its runtime source folders to the MATLAB path using absolute paths; returns the repository root. It deliberately excludes archived examples, tests and docs. |
| [landing_gear_loads.m](src/analysis/landing_gear_loads.m) | Optional analysis | Calculates generic tricycle nose/main static-load worst cases from assumed geometry ratios. It is not a float structural or buoyancy model and is not needed for the mission. |
| [wing_fuel_check.m](src/analysis/wing_fuel_check.m) | Optional analysis | Compares required fuel with the geometric wing-tank volume estimate times fuel density. Separate from run_profile's published usable-fuel-capacity margin. |
| [constraint_climb.m](src/constraints/constraint_climb.m) | Combined | Computes allowable W/P for a prescribed climb gradient, using configured drag/lift, propeller efficiency, weight ratio and available engine power. |
| [constraint_cruise_speed.m](src/constraints/constraint_cruise_speed.m) | Combined | Computes allowable W/P at the cruise requirement, using either the power-index correlation or the aircraft drag-based shaft-power balance. |
| [constraint_landing.m](src/constraints/constraint_landing.m) | Combined | Converts required landing distance to allowable stall speed and a maximum takeoff W/S. It is also a generic surrogate, not float hydrodynamics. |
| [constraint_takeoff.m](src/constraints/constraint_takeoff.m) | Combined | Converts required distance into a generic takeoff parameter and maximum allowable W/P versus W/S. Here it is a runway-based water-distance surrogate. |
| [matching_envelope.m](src/constraints/matching_envelope.m) | Combined | Takes the tightest power-loading limits and wing-loading wall, then selects the feasible sampled point with greatest W/P (least installed power per unit weight). |
| [run_constraints.m](src/constraints/run_constraints.m) | Combined | Evaluates every condition and dispatches to takeoff, landing, climb-gradient or cruise-speed constraint functions; returns power limits and wing-loading walls. |
| [wing_loading_sweep.m](src/constraints/wing_loading_sweep.m) | Combined | Reads the wing-loading grid from active JSON, evaluates the landing wall and appends that wall just inside its bound before envelope selection. |
| [AerodynamicsBase.m](src/framework/AerodynamicsBase.m) | Mission | Abstract aerodynamic interface and reusable aerodynamic relations inherited by TtpaAero. |
| [AircraftState.m](src/framework/AircraftState.m) | Mission | Computes dry ISA troposphere temperature, pressure, density, speed of sound and Mach-dependent state quantities without Aerospace Toolbox. |
| [GeometryBase.m](src/framework/GeometryBase.m) | Mission | Abstract geometry interface and reusable planform identities required by TtpaGeom, including span, root/tip chord and mean aerodynamic chord. |
| [get_state.m](src/framework/get_state.m) | Mission | Returns altitude, density and density ratio for mission/constraint calculations; caches repeated atmosphere states. |
| [PropulsionBase2.m](src/framework/PropulsionBase2.m) | Mission | Abstract propulsion interface and handle-class parent required to instantiate TtpaProp and validate injected propulsion objects. |
| [ttpa_disciplines.m](src/framework/ttpa_disciplines.m) | Mission | Constructs linked propulsion, geometry, aero and weight models, initializes reference power/area/weight, and imports both the mission and conditions. |
| [WeightsBase.m](src/framework/WeightsBase.m) | Mission | Abstract empty-weight/payload interface inherited by TtpaWeights. |
| [ConstraintSetImporter.m](src/io/ConstraintSetImporter.m) | Mission | Imports and normalizes the constraint conditions. Required even for run_profile because the existing discipline factory always loads both mission and constraints. |
| [get_con.m](src/io/get_con.m) | Combined | Extracts one condition, maps altitude keys, and supplies defaults for configuration, weight ratio, engine-out flag, rating, throttle and cruise method. |
| [get_miss_seg.m](src/io/get_miss_seg.m) | Mission | Extracts one mission segment and maps JSON names such as alt_ft and distance_nm to the fields used by segment functions. |
| [json_as_struct_array.m](src/io/json_as_struct_array.m) | Mission | Converts JSON cell/structure collections into one structure array, filling missing fields so unlike segment/condition objects can coexist. |
| [MissionProfileReader.m](src/io/MissionProfileReader.m) | Mission | Loads missions.std_mission from JSON and normalizes heterogeneous segment objects into a consistent structure array. |
| [ttpa_requirements_path.m](src/io/ttpa_requirements_path.m) | Mission | Finds config/GrandCaravanEX_requirements_IHW3.json relative to this checkout, independent of the Current Folder. |
| [validate_caravan_json.m](src/io/validate_caravan_json.m) | Mission | Checks required blocks, single-engine EX selection, key propulsion inputs, mission segment types, altitudes, speeds and discretization counts. |
| [mission_fuel.m](src/mission/mission_fuel.m) | Mission | Chooses L1 or L2 mission implementation, aggregates segment fuel, applies the additional reserve multiplier and rejects invalid weight histories. |
| [run_mission.m](src/mission/run_mission.m) | L1 option | Older Level-1 implementation with fixed climb fraction and simplified cruise/loiter aerodynamic assumptions. Not selected by the active L2 profile; retain to keep the documented L1 option. |
| [run_mission_L2.m](src/mission/run_mission_L2.m) | Mission | Dispatches the eight profile segments by type. Uses calculated climb/cruise/loiter fractions and fixed takeoff/descent/landing fractions. |
| [segment_climb_L2.m](src/mission/segment_climb_L2.m) | Mission | Integrates climb in altitude bands using excess propulsive power, estimating climb time, fuel burned and outgoing weight; fails if climb power is insufficient. |
| [segment_cruise_L2.m](src/mission/segment_cruise_L2.m) | Mission | Uses subsegment Breguet cruise with actual weight-dependent CL and drag polar at the specified speed/altitude; reports fuel and average aerodynamic quantities. |
| [segment_loiter_L2.m](src/mission/segment_loiter_L2.m) | Mission | Uses Breguet endurance at the loiter speed/altitude and entry lift-to-drag ratio to calculate the loiter weight fraction. |
| [TtpaAero.m](src/models/TtpaAero.m) | Mission | Builds clean and configured drag polars, float drag increment, Oswald efficiency, induced-drag factor, CL limits and maximum lift-to-drag ratio from geometry and inputs. |
| [TtpaGeom.m](src/models/TtpaGeom.m) | Mission | Computes wing/tail planforms, fuselage/nacelle dimensions, exposed and wetted areas, and estimated wing fuel volume. Dependent properties update when S_ref or engine power changes. |
| [TtpaProp.m](src/models/TtpaProp.m) | Mission | PT6A-140 proxy: altitude/rating power availability, BSFC, propeller efficiency and engine weight/length scaling. P_SL is mutable total rated shaft power. |
| [TtpaWeights.m](src/models/TtpaWeights.m) | Mission | Builds the calibrated empty weight from components, float proxy and calibration residual; stores payload and candidate fuel/takeoff weights. The anchor is not an independent weight prediction. |
| [grand_caravan_ex_benchmark.m](src/reference/grand_caravan_ex_benchmark.m) | Combined | Reports reference arithmetic such as W/S, W/P, aspect ratio, empty fraction and remaining payload with full fuel. Does not fly the mission. |
| [grand_caravan_ex_check_json.m](src/reference/grand_caravan_ex_check_json.m) | Combined | Checks selected EX reference fields and engine-out constraint removal, then reports benchmark and illustrative mission inputs. Defaults to the active config path. |
| [grand_caravan_ex_params.m](src/reference/grand_caravan_ex_params.m) | Mission | Reference aircraft parameters and explicitly provisional modeling constants, including float-related quantities; used by several model classes. |
| [grand_caravan_ex_initial_opts.m](src/sizing/grand_caravan_ex_initial_opts.m) | Sizing | Supplies reference starting weight/power/area, sweep, tolerance, iteration limit and tested relaxation for the simple sizing entrypoint. |
| [sizing_mainloop.m](src/sizing/sizing_mainloop.m) | Sizing | Repeats sizing passes with relaxation until weight, power and wing area residuals converge; returns history and synchronizes final model states. |
| [sizing_pass.m](src/sizing/sizing_pass.m) | Sizing | One sizing iteration: writes current power/area, evaluates constraints, proposes engine/wing sizes, flies the mission, evaluates empty weight and proposes gross weight. |
| [sizing_snapshot.m](src/sizing/sizing_snapshot.m) | Sizing | Creates a detailed record of each sizing pass: geometry, engine, drag, weights, fuel, proposed sizes and convergence residuals. |
| [SizingSteps.m](src/sizing/SizingSteps.m) | Sizing | Static helpers for gross-weight closure and under-relaxation; returns NaN if fuel plus empty weight consumes all candidate gross weight. |
| [test_caravan.m](tests/test_caravan.m) | Tests | Eight original regression tests for atmosphere, reference anchoring, geometry/aero coupling, mission balance, cruise constraint, closure/sizing, invalid inputs and inability to climb. |
| [test_repository_layout.m](tests/test_repository_layout.m) | Tests | Checks that mission execution finds JSON from another Current Folder, matches the original combined runner's mission fuel, and preserves the user's 3-degree initial climb-gradient input. |
| [verify_project.m](verify_project.m) | Verification | Scans all MATLAB files for syntax errors, runs tests, audits dependencies and demonstrates sizing. Writes logs and MAT results into outputs/. |

## Calculation flow and outputs

`run_profile -> setup_project -> ttpa_disciplines -> mission_fuel -> run_mission_L2 -> segment calculations`. The factory builds propulsion first, then geometry, aero and weights, so linked models see changes to shared power and wing area. The original combined runner also calls `wing_loading_sweep -> matching_envelope -> run_constraints`. Optional sizing repeats constraints, mission and empty-weight evaluation to propose a new weight, power and area.

For each segment, `wf = weight_after / weight_before`, and fuel burned is `weight_before * (1-wf)`. The overall mission fraction is `prod(result.wf)`. Extra reserve fuel is applied by `mission_fuel` according to the active JSON. The default additional reserve fraction is zero because a 45-minute loiter is explicitly included. The battery/hybrid energy calculations discussed in separate projects are not part of this repository.

`mass_margin_lb` is takeoff weight minus modeled empty weight, payload and required fuel. `tank_margin_lb` compares required fuel with the 2246-lb reference usable capacity. Positive margins establish those bookkeeping checks only. `run_caravan` also returns the constraint envelope and selected W/S, W/P. `run_caravan(true)` resizes the airplane; its converged geometry and power need not equal the real Caravan.

## Model assumptions and limitations

This is an instructional conceptual model. Empty weight is anchored to 5975 lb using an unallocated calibration residual; it is not an independently predicted operating-empty weight. Float drag is a provisional CD0 increment of 0.012; the 665-lb float/configuration proxy is a net landplane/amphibian empty-weight difference, not a measured float assembly mass. Water takeoff/landing constraints use runway correlations as surrogates. Propulsion BSFC, altitude lapse, propeller efficiencies, wetted area and component weights contain provisional assumptions.

L2 climb uses excess power and a minimum-power CL, without a full stall/speed/thermal schedule. Cruise and loiter do not independently enforce all operational power/stall limits. Fixed ground/descent fractions are retained. No validated water hydrodynamics, buoyancy, stability, structural or certification analysis is provided. See the active JSON's `model_assumptions` block and archived original README for fuller context.

## GitHub upload

Upload the **contents of this repository folder**, keeping its subfolders intact. Do not upload the outer ZIP as the only repository file. Include hidden `.gitignore` and `.gitattributes` files; generated files in `outputs/` and MATLAB `.mat` outputs are excluded.

A simple GitHub Desktop workflow is to create a repository in a new empty local folder, copy this organized folder's contents into that repository, review the files, commit with a message such as `Add organized Grand Caravan amphibian MATLAB model`, and publish to the GitHub repository you choose. Publishing is left to the user. This delivery does not create a remote repository or upload files.

The command-line alternative, from the organized repository root, is:

```text
git init
git add .
git commit -m "Add organized Grand Caravan amphibian MATLAB model"
git branch -M main
```

After creating an empty GitHub repository, use the remote URL that GitHub supplies:

```text
git remote add origin YOUR_GITHUB_REPOSITORY_URL
git push -u origin main
```

Replace the URL placeholder before running the last two commands. No license was selected automatically. The existing source/provenance notes have been retained.

## What changed during organization

All original MATLAB files are retained. Aircraft equations and the active JSON are preserved. Changes are limited to project setup, config-path lookup, benchmark input-path default and verifier output/search paths. The added `run_profile` gives the requested mission-only workflow. The original source MAT result was omitted as a generated artifact; historical text verification and original documentation are retained. `docs/provenance/REORGANIZATION.json` maps every original MATLAB file to its new location and records hashes, including the small path-related edits.

The original `PROVENANCE.json` describes an earlier adaptation; it is historical, not a current file-location manifest. The new reorganization manifest is authoritative for this folder layout. Fresh verification outputs go into `outputs/`; an intentionally retained text report under `docs/verification/` documents the reviewed release without committing binary result files.


Reviewed organization verification: **10 tests passed in MATLAB R2025a Update 1**, with mission fuel approximately 1550.3 lb and sizing convergence in 127 iterations for the preserved rev0 JSON. A separate fresh MATLAB run verified the optional-file classification using a reduced 26-file mission runtime. See [the reviewed report](docs/verification/ORGANIZED_VERIFICATION.txt).
