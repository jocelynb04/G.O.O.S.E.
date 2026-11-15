# Concept 4 — Series-Hybrid Amphibious Seaplane — Preliminary MATLAB Model

This folder contains **Concept 4**, the series-hybrid-electric, twin-float amphibious aircraft being evaluated for Virginia Tech Aerospace Engineering Senior Design (THW5 / pre-CoDR). Its preliminary configuration has **six distributed electric propulsion motors**, one turbogenerator, a battery, and a cruciform tail. This is **one of four team aircraft concepts**; the 300-ft² and 325-ft² wing configurations discussed below are **variants within Concept 4**, not additional concepts or a final selection.

The model combines geometry, aerodynamic drag, preliminary hydrodynamics, series-hybrid power flow, mission energy and fuel, component empty weight, and constraint/sizing calculations. **Numerical convergence does not establish that the aircraft meets every RFP requirement.**

## Run the Concept 4 model

Use a recent MATLAB release that supports `jsondecode`, `table`, `writetable`, and `exportgraphics` (a MATLAB release has **not** been independently qualified for this packaged version). Clone/extract the folder and set MATLAB **Current Folder** to `Concept_4`, where the `.m` files and both active JSON inputs are located. If previously loaded classes have changed, run `clear classes` before rerunning. Do not add archived IHW3 examples containing duplicate function names to the active MATLAB path.

To reproduce the **pre-downselect wing-area comparison** and generate the constraint figure:

```matlab
out = run_concept4_predownselect;
disp(out.comparison)
```

The default run evaluates **300, 325, and 350 ft²** using the active assumptions, saves each fixed-wing coupled-sizing run, produces a candidate comparison, and annotates the 12,500-lb matching diagram. `out.comparison` contains wing area, span, estimated takeoff weight, motor and generator ratings, battery capacity/mass, mission fuel, SOC, weight margin, trial liftoff speed, and preliminary status.

To evaluate one wing area independently:

```matlab
light300 = run_concept4_lightweight_fixedwing(300);
light325 = run_concept4_lightweight_fixedwing(325);
```

To generate the standalone **mission constraint diagram**, or the additional cruise/climb motor and generator sweeps:

```matlab
constraints = run_concept4_constraint_diagram_style;
sweep = run_concept4_constraints_12500;
```

To reproduce the **original, heavier legacy sizing approach**, kept as a baseline rather than the current lightweight candidate method:

```matlab
legacy = run_concept4_sizing;
plot_concept4_results
```

For component/integration and current-input tests:

```matlab
test_concept4_integration
addpath('tests')
test_concept4_predownselect_inputs
run_concept4_smoke
```

These tests check selected interfaces and assumptions; they are **not** complete aircraft verification. No external framework or MATLAB toolbox is intentionally called by the current functions, but the supplied package has **not been rerun independently in MATLAB**. User-observed MATLAB outputs are distinguished from independently checked results below.

## Repository organization

The current Concept 4 integration uses a **flat MATLAB source folder**. The structure below describes the supplied pre-downselect package, not the more deeply nested directory structure of the comparator aircraft repository.

```text
Concept_4/
  README.md                           this guide
  concept4_aero_hydro_requirements.json   active requirements, geometry, propulsion, aero, sizing inputs
  concept4_integration_assumptions.json   active operating assumptions and sizing margins
  run_concept4_predownselect.m        three-wing comparison and annotated constraint diagram
  run_concept4_lightweight_fixedwing.m fixed-wing coupled sizing and mission-weight sensitivity
  run_concept4_constraint_diagram_style.m  power-loading matching diagram
  run_concept4_constraints_12500.m    motor/generator rating constraint sweep
  run_concept4_sizing.m               original coupled sizing entrypoint (legacy method)
  run_concept4_smoke.m                basic smoke test
  plot_concept4_results.m            plots from original sizing CSV outputs
  Concept4Sizing.m                   original weight/power/area iteration class
  Concept4Mission.m                  mission phase dispatch and fuel/SOC accounting
  Concept4Verification.m             preliminary RFP status screen for legacy results
  Concept4Constraints.m              adapter to original matching envelope
  Concept4GeometryAdapter.m          adapter to geometry class
  SeaplaneGeom.m                      wing, tails, fuselage, floats and nacelle geometry
  SeaplaneAero_Concept4.m            drag buildup and configuration polars
  SeaplaneHydro_Concept4.m           buoyancy, hydrostatics and planing-only resistance
  SeaplaneProp_Concept4.m            series-hybrid bus, battery, generator and motor model
  SeaplaneWeights.m                  component OEW and payload estimates
  matching_envelope_C4.m             original aero matching and scoring approach
  constraint_cruise_speed_C4.m       required cruise shaft power
  c4_required_climb_hp.m             minimum required shaft power over climb-speed sweep
  segment_climb_C4.m                 mission climb segment
  segment_cruise_C4.m                mission cruise segment
  segment_loiter_C4.m                mission loiter segment
  isa_atmosphere_C4.m                ISA properties
  c4_get.m                           optional structure-field access
  c4_segments.m                      mission segment array conversion
  sizing_pass.m                      adapter for original single sizing pass
  sizing_mainloop.m                  adapter for original iterative sizing
  write_json_C4.m                    JSON output writer
  test_concept4_integration.m         component/integration checks
  tests/
    test_concept4_predownselect_inputs.m  active-input consistency checks
  docs/
    ASSUMPTIONS.md                    assumptions, units, authority and validation status
    METHODS_AND_LIMITATIONS.md        implemented methods and verification gaps
    RESULTS_AND_DECISIONS.md          dated candidate results and design decisions
    SOURCES_AND_VALIDATION.md         literature, comparators and evidence needed
  results/                             generated locally, excluded by .gitignore
  .gitignore                          excludes generated results and MATLAB autosaves
```

Input files are read relative to the `.m` entrypoint's directory by the current runners, so keep the active JSON files beside the source files. Do **not** substitute the original classroom piston-aircraft requirements JSON. The older sizing path and candidate path intentionally remain separate for method comparison.

## Which files do I actually need?

For GitHub, retain the full active MATLAB code, both JSON inputs, tests, and documentation. The entrypoints call supporting classes and functions; individual helper files are **not separate programs to run**.

| Item | Needed for `run_concept4_predownselect`? | Recommendation |
|---|---|---|
| `run_concept4_predownselect.m` | Yes | Main pre-downselect entrypoint; keep |
| `run_concept4_lightweight_fixedwing.m` | Yes | Runs the coupled candidate sizing; keep |
| `run_concept4_constraint_diagram_style.m` | Yes | Creates the annotated matching figure; keep |
| Both `concept4_*.json` files | Yes | **Active input/source of truth**; keep under version control |
| `SeaplaneGeom`, `SeaplaneAero_Concept4`, `SeaplaneProp_Concept4`, `SeaplaneWeights`, `Concept4Mission` | Yes | Linked engineering disciplines; keep all |
| `c4_required_climb_hp`, `constraint_cruise_speed_C4`, mission segment files, `isa_atmosphere_C4`, `c4_get`, `c4_segments`, `write_json_C4` | Yes / used by called routines | Keep; necessary supporting functions |
| `SeaplaneHydro_Concept4.m` | No for the candidate mass calculation | Keep: buoyancy/planing investigation is important but **not** a complete takeoff model |
| `run_concept4_sizing.m`, `Concept4Sizing.m`, `matching_envelope_C4.m`, `sizing_mainloop.m`, `sizing_pass.m`, `Concept4Verification.m` | No for lightweight candidates | Keep as **legacy baseline and verification context**, not the lightweight result |
| `run_concept4_constraints_12500.m`, `Concept4Constraints.m`, `Concept4GeometryAdapter.m` | Not required by main candidate entrypoint | Keep as standalone/adapter analysis |
| `plot_concept4_results.m`, `run_concept4_smoke.m` | No | Keep for legacy plots and component checks |
| Tests and `docs/` | No for ordinary execution | Keep for reproducibility, assumptions and review |
| `results/` outputs (`.csv`, `.json`, `.fig`, `.png`) | No; regenerated locally | Leave ignored unless the team intentionally commits selected, dated report figures |

## What every MATLAB file means

**Pre-downselect** denotes the currently relevant candidate workflow; **Legacy** identifies the original sizing route retained for comparison; **Model/mission** means a supporting discipline; **Constraint** means a cruise/climb calculation; **Test** means a diagnostic, not an RFP pass certificate.

| File | Use | Purpose |
|---|---|---|
| [`run_concept4_predownselect.m`](run_concept4_predownselect.m) | Pre-downselect | Runs the configured wing-area variants, assembles a comparison table, calls the matching-diagram plotter, and saves annotated figures and CSV. |
| [`run_concept4_lightweight_fixedwing.m`](run_concept4_lightweight_fixedwing.m) | Pre-downselect | Iterates estimated gross weight for one fixed wing area; resizes motor/generator at no less than the team 12,500-lb performance screening weight; sizes battery energy and adjusts mass using the modeled mission peak power. |
| [`run_concept4_constraint_diagram_style.m`](run_concept4_constraint_diagram_style.m) | Constraint/plot | Creates Caravan-style wing-loading vs. electric-motor power-loading chart, with all-motors-operating (AEO) cruise/climb curves, span walls, the initial guess and an optimistic unverified motor-out reference. |
| [`run_concept4_constraints_12500.m`](run_concept4_constraints_12500.m) | Constraint | Exports fixed-12,500-lb motor and turbogenerator rating sweeps, W/P plot and candidate data. |
| [`run_concept4_sizing.m`](run_concept4_sizing.m) | Legacy | Original integrated sizing runner; writes sizing history, mission segment records, matching data and RFP status under `results/`. |
| [`Concept4Sizing.m`](Concept4Sizing.m) | Legacy | Original coupled weight, wing-area, motor, generator, battery-energy sizing class; uses original envelope selection and installed battery mass method. |
| [`matching_envelope_C4.m`](matching_envelope_C4.m) | Legacy/constraint | Samples wing loading, computes cruise/climb and idealized motor-out power requirements, then selects using an exploratory score; motor-out drag/yaw effects are not verified. |
| [`sizing_pass.m`](sizing_pass.m) | Legacy adapter | Calls one pass of `Concept4Sizing.sizing_pass`. |
| [`sizing_mainloop.m`](sizing_mainloop.m) | Legacy adapter | Calls the iterative `Concept4Sizing.run` method. |
| [`Concept4Verification.m`](Concept4Verification.m) | Legacy verification | Produces preliminary status checks for payload, span, climb, cruise, mission and unresolved RFP requirements. A pass means a model screen, not physical verification. |
| [`Concept4Mission.m`](Concept4Mission.m) | Mission | Steps through taxi, takeoff, climb, cruise, descent, balked landing, loiter and landing; accumulates fuel, battery bus loads, battery SOC and peak energy deficit. |
| [`SeaplaneProp_Concept4.m`](SeaplaneProp_Concept4.m) | Model | Converts required shaft hp to electric bus power; distributes load between generator and battery, tracks SOC/fuel, and estimates installed propulsion masses. |
| [`SeaplaneGeom.m`](SeaplaneGeom.m) | Model | Derives span, chords, tails, fuselage geometry, float/strut/pod geometry and estimated wetted areas from active configuration and wing area. |
| [`SeaplaneAero_Concept4.m`](SeaplaneAero_Concept4.m) | Model | Builds component parasite drag and induced drag from reference geometry; provides flap/gear polars, lift limits, and forces for flight and water-run screens. |
| [`SeaplaneHydro_Concept4.m`](SeaplaneHydro_Concept4.m) | Optional hydro | Screens buoyancy and hydrostatics; implements a Savitsky-type *steady-planing* resistance estimate with validity limits. Does **not** calculate full water takeoff. |
| [`SeaplaneWeights.m`](SeaplaneWeights.m) | Model | Estimates component operating empty weight and the required fixed occupant/baggage payload. |
| [`Concept4Constraints.m`](Concept4Constraints.m) | Adapter | Calls the original `matching_envelope_C4` function. |
| [`Concept4GeometryAdapter.m`](Concept4GeometryAdapter.m) | Adapter | Constructs the Concept 4 `SeaplaneGeom` object. |
| [`constraint_cruise_speed_C4.m`](constraint_cruise_speed_C4.m) | Constraint | Computes required cruise shaft hp at specified weight, area, altitude and KTAS from drag and propulsive efficiency. |
| [`c4_required_climb_hp.m`](c4_required_climb_hp.m) | Constraint | Sweeps eligible climb speeds and identifies minimum shaft hp for a specified rate of climb. |
| [`segment_climb_C4.m`](segment_climb_C4.m) | Mission helper | Computes climb segment speed and power using aerodynamic polar, altitude and climb rate. |
| [`segment_cruise_C4.m`](segment_cruise_C4.m) | Mission helper | Computes level-cruise shaft power at a specified speed and altitude. |
| [`segment_loiter_C4.m`](segment_loiter_C4.m) | Mission helper | Computes loiter shaft power at a specified speed and altitude. |
| [`isa_atmosphere_C4.m`](isa_atmosphere_C4.m) | Utility | Calculates ISA atmosphere temperature, density, viscosity and speed of sound through the implemented altitude range. |
| [`c4_get.m`](c4_get.m) | Utility | Returns a structure field or a provided fallback value. |
| [`c4_segments.m`](c4_segments.m) | Utility | Converts JSON-decoded mission segment data to a consistent cell array. |
| [`write_json_C4.m`](write_json_C4.m) | Utility | Writes MATLAB structures as JSON to the requested path. |
| [`plot_concept4_results.m`](plot_concept4_results.m) | Plot/legacy | Generates weight-convergence, mission SOC and matching-power plots from the legacy run's CSV files. |
| [`run_concept4_smoke.m`](run_concept4_smoke.m) | Test | Performs a simple initial geometry, aero, buoyancy, OEW and mission-probe calculation. |
| [`test_concept4_integration.m`](test_concept4_integration.m) | Test | Asserts baseline discipline interfaces, payload, drag and mission behavior, and existence of a sampled original matching envelope. |
| [`tests/test_concept4_predownselect_inputs.m`](tests/test_concept4_predownselect_inputs.m) | Test | Checks active architecture, payload, team weight target, battery margin, wing variants, span/takeoff requirements and basic parameter consistency. |

## Calculation flow and generated outputs

**Candidate workflow:** `run_concept4_predownselect` → `run_concept4_lightweight_fixedwing(wing area)` → geometry / aerodynamics / propulsion / weights → cruise and climb rating screens → `Concept4Mission` energy sizing probe → mission run → battery mass/installation adjustment → gross weight iteration → candidate summary. The top-level runner also calls `run_concept4_constraint_diagram_style` and saves a comparison table.

At each fixed-wing sizing pass, the performance-screen weight is `max(estimated gross weight, 12,500 lb)`, while the mission energy/fuel calculation uses the **actual iterative gross weight**. The all-motors-operating installed rating includes a motor continuous-rating fraction and a small power margin. Battery mass is calculated from the **greater of energy-based mass and mission-peak-power-based mass**, with the provisional 10% power margin in `concept4_integration_assumptions.json`. The candidate runner applies this battery mass as an OEW correction; **the legacy `Concept4Sizing`/propulsion installed-mass route has not been replaced**.

The model closes mass according to

```text
calculated takeoff weight = estimated operating empty weight + payload + mission fuel
mass closure residual = iterated takeoff weight − calculated takeoff weight
```

A small residual means the equations are self-consistent **under the input assumptions**. It does not validate component hardware mass, water takeoff, or certification performance.

Generated files (not active inputs):

| Output | Produced by | Meaning |
|---|---|---|
| `results/fixedwing_300/summary.json`, `iteration_history.csv` | 300-ft² sizing | Candidate weight, power, battery, SOC and convergence history |
| `results/fixedwing_325/summary.json`, `iteration_history.csv` | 325-ft² sizing | Same outputs for the larger-wing variant |
| `results/fixedwing_350/summary.json`, `iteration_history.csv` | Optional/default comparison | Third sensitivity, not a selected candidate |
| `results/predownselect/candidate_comparison.csv` | Top-level comparison | Cross-variant data and statuses |
| `results/predownselect/concept4_predownselect_candidates.fig/.png` | Top-level comparison | Matching diagram annotated with weight-eligible variants |
| `results/constraints_12500/` | Constraint functions | Matching curves and data at the team screening weight |
| `results/sizing_results.json`, `sizing_history.csv`, `mission_segments.csv`, `RFP_status.json` | Legacy sizing | Original baseline; **not** the lightweight candidate result |

## Preliminary reference results — 15 November 2026

The following numbers are **observed results from the working MATLAB session**, not independently rerun verification of this packaged source. Re-run the code after changing any input.

| Quantity | Concept 4A | Concept 4B |
|---|---:|---:|
| Fixed wing area | **300 ft²** | **325 ft²** |
| Wingspan | 48.99 ft | 50.99 ft |
| Coupled estimated takeoff weight | **~12,398 lb** | **12,442.19 lb** |
| Margin below team 12,500-lb target | ~102 lb | 57.81 lb |
| Total installed motor rating | ~1,606.7 shp | 1,580.94 shp |
| Turbogenerator engine rating | ~1,025.1 shp | 1,019.25 shp |
| Estimated battery mass | ~939.46 lb | 939.46 lb |
| Modeled mission fuel | ~1,606 lb | 1,573.94 lb |
| Trial liftoff speed | ~99 kt | ~95 kt |
| Water takeoff distance over 50-ft obstacle | **Not verified** | **Not verified** |

The 300-ft² aircraft is slightly lighter, whereas the 325-ft² wing has a lower trial liftoff speed. Both margins are smaller than likely conceptual-model uncertainty. **Neither variant has been chosen as the team's aircraft, nor has Concept 4 been selected over the other three team concepts.** The original model's ~15,604-lb result is retained as a different, legacy sizing-method baseline.

The full-distance mission is modeled as **868.976 nmi (1,000 statute miles)** at a preliminary **130 KTAS / 10,000 ft**, with a separate **180-KTAS / 10,000-ft** required cruise-capability screen, an explicit electric-only balked landing at reserve entry, and a 45-minute reserve. Payload is **2,430 lb** for nine passengers and two pilots with the stated baggage allowance. These mission inputs and phase assumptions are documented in the active JSON and `docs/ASSUMPTIONS.md`.

## Model assumptions and limitations

This is a **preliminary design-trade model**, not a flight-test, CFD, water-tank-tested, hardware-validated, or certification-compliant design. The **12,500-lb target is a team design objective**, not an RFP/certification maximum. Binding performance requirements include cruise/climb capability, wingspan below 65 ft, electric-only water operations, and a **2,000-ft water takeoff including clearance of 50 ft**, among other RFP conditions.

The most consequential unverified assumption is **900 shaft hp for two minutes of water takeoff**. The resulting peak mission battery bus demand, about **736 kW**, is imposed by this provisional profile; it is not derived from float hump drag, low-speed propeller thrust, water acceleration, rotation, or obstacle clearance. The smaller-wing variants also require higher trial liftoff speeds. The implemented planing correlation is not applicable over the complete water run and cannot establish the takeoff requirement. Water landing distance likewise remains unverified.

Other limitations include placeholder pack-level battery specific power/energy, turboshaft BSFC and lapse, fixed propulsion efficiencies, float and amphibious gear weight estimates, approximate wetted area pending OpenVSP, unsolved stopped-propeller drag/yaw during motor-out flight, failure/endurance contingencies, flooding/heel/buoyancy below the cabin floor, operational recharge/no-shore-charge, noise, sea state, IFR/FIKI, and cabin/egress checks. The green feasible region on the matching diagram is **only an AEO motor-power and span screen**, not a full-aircraft feasibility region.

See [`docs/ASSUMPTIONS.md`](docs/ASSUMPTIONS.md) for active values and provenance, [`docs/METHODS_AND_LIMITATIONS.md`](docs/METHODS_AND_LIMITATIONS.md) for equations and gaps, [`docs/SOURCES_AND_VALIDATION.md`](docs/SOURCES_AND_VALIDATION.md) for literature and missing validation evidence, and [`docs/RESULTS_AND_DECISIONS.md`](docs/RESULTS_AND_DECISIONS.md) for dated design status.

## GitHub upload

Add this material to the **existing team G.O.O.S.E. repository's Concept 4 folder**, not to the comparator's Cessna 208 directory, and do not overwrite your teammates' Concepts 1–3. Review code/JSON changes on a dedicated branch, preserving the original baseline route and clearly identifying candidate-specific results. Keep generated `results/` excluded unless your team decides to commit a small set of dated, curated figures for the report.

From the **team repository root** (adjust the relative folder path to match the checkout):

```bash
git switch -c concept4-thw5-predownselect
git add code/THW5/Concept_4/
git diff --cached --stat
git commit -m "Document Concept 4 preliminary hybrid sizing and wing trade"
git push -u origin concept4-thw5-predownselect
```

Use GitHub Desktop if preferred; the important steps are review, commit, push and teammate review before merge. **These commands are instructions only; generating this README does not update the remote repository.** The README and source files can be committed; the output files are reproducible locally.

## What changed in the pre-downselect study

The original integrated model selected a large wing to minimize motor rating and sized battery mass using the **full installed motor-power** assumption, converging near **15,604 lb**. The separate candidate workflow instead tests specified wing areas and evaluates battery mass against the greater of mission energy and modeled peak battery electrical power. An additional correction ensures motor/generator sizing is evaluated at **no less than 12,500 lb** even if the mass iteration closes below that weight. This produced preliminary 300-ft² and 325-ft² candidates that close below the team's objective in the user-observed MATLAB runs.

These improvements are **analysis-method changes**, not proof of lighter verified hardware. They must be validated before being merged into the main `Concept4Sizing.m` model or used to claim compliance in the CoDR downselect. The next major task is source-supported water takeoff analysis and higher-fidelity float/propulsion/weight data, followed by a common-method comparison against the other three aircraft concepts.
