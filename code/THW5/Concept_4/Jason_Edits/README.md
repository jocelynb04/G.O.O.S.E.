# Concept 4 Jason Edits

This is an isolated copy of Concept 4 synchronized to **Seaplane_Concept04.vsp3**. All original files outside this folder are preserved. The geometry is matched to the CAD. Performance coefficients, hardware properties and structural mass correlations remain preliminary.

## Run the analysis

Set MATLAB's current folder to `Concept_4/Jason_Edits` and run **`untitled`** or:

```matlab
[analysis,hist] = matchingdiagram();
```

For a hidden-window run:

```matlab
analysis = run_concept4_study(Visible=false);
```

`hist` is empty because the main study evaluates a fixed CAD aircraft at **12,490 lb**. It computes a mass buildup and source/mission screen. It does not claim a fully coupled weight convergence or resize the wing to make the result fit.

## Geometry used

| Item | OpenVSP baseline |
|---|---:|
| Wing area | 325 ft² |
| Wing span | 64 ft |
| Wing aspect ratio | 12.6031 |
| Wing mean aerodynamic chord | 5.389 ft |
| Horizontal tail area and span | 62.868 ft² and 18.6 ft |
| Vertical tail area and height | 61.3731 ft² and 8.94 ft |
| Fuselage length width height | 41 × 7 × 6.2 ft |
| Pontoons | Two, each 27 × 4 × 3 ft |
| Pontoon exterior volume | 393.317 ft³ total |
| Motor pods | Six, each 10 ft long and about 1.333 ft diameter |
| Propellers | Six, 4 ft diameter, three blades each |

The old AR 8 input produced a 50.99-ft span at 325 ft². That configuration is not the current CAD baseline. Imported dihedral/twist, tail planforms and arms, body segmentation, pod dimensions and intersected wetted areas now feed the geometry and drag calculations.

Native OpenVSP CompGeom supplies the exposed wetted areas. Rotating propeller blade area is excluded from airframe parasite drag. Native DegenGeom supplies tail-station estimates. Stored analysis meshes are removed only in the transient extraction process. The original OpenVSP file is not edited. Dimensions are interpreted as feet, consistent with the project's aircraft geometry convention.

`verify_openvsp_geometry` checks 24 dimensions/counts/areas against the native export reference. It also checks the imported model checksum and the original source checksum when that source path is available. A changed model stops the check rather than silently accepting stale geometry.

Across a constraint wing-loading sweep, only the wing area/span/chords and proportional wing wetted area vary. The CAD fuselage, tails, floats, struts and pods stay fixed. These sweep points are a virtual sizing family, not additional imported aircraft.

## Constraint plot format

The figures follow the Caravan comparator's layout: white axes, blue sea-level climb, green altitude climb, orange balked landing, cyan cruise, a yellow reference star, labeled axes, grid, legend and aircraft summary box. Main plots are:

- `Results/Current/concept4_matching_diagram.png`, `.pdf`, `.fig`: motor nameplate-power loading.
- `Results/Current/concept4_generator_constraints.png`, `.pdf`, `.fig`: generator-engine nameplate-power loading.

The editable `.fig` files can be opened in MATLAB. CSV/MAT exports preserve the curve data and the exact reference ratings. The axes use 12,490 lb consistently with the plotted reference point. Motor shaft rating and generator-engine shaft rating are separate quantities and are never added as simultaneous propeller shaft power.

**Green means flight-power sizing screen only.** It does not establish water takeoff/landing, mission energy, mass closure or full failure feasibility. The dashed red 450-fpm curve is a one-motor-out ideal screen excluding failed-propeller drag and yaw. Losing the single generator is a different failure; its battery-only endurance remains unresolved.

The water-landing wall uses an explicitly assumed **0.15-g** deceleration, a 3-degree approach, a 50-ft obstacle, a 10-ft flare entry, a 150-ft flare allowance and touchdown speed 1.15 times stall speed. It is a provisional water stopping proxy, not the old 75-KIAS vertical stall screen, an AFM result, or a validated hydro model. The CAD reference exceeds this proxy's permitted wing loading. Water takeoff remains an assumed power/time schedule; no water takeoff-distance curve is fabricated.

## Current preliminary result

The native-geometry run predicts approximately **12,129 lb** for the full 2,430-lb payload and target 1,000-statute-mile cruise mission with the modeled reserve branch. This leaves about **361 lb to 12,490**. The model selects approximately 1,489 hp total motor nameplate, one 950-hp generator engine, 115.28 kWh battery nameplate and 939.5 lb battery mass. These are calculated study ratings, not qualified hardware selections.

This result supersedes the old AR-8/325-ft² result only for this new CAD-matched copy. It is a fixed-weight buildup, not a new maximum-range result or proof of RFP compliance. The imported 64-ft span still needs a structural design: the inherited wing area-based weight correlation does not establish the cost of the larger span or aeroelastic loads.

The following remain open: water distances and spray, generator/motor/bus failure endurance and control, repeated-route recharge, approach and arrival energy completeness, battery temperature/aging capability, full integration mass, damage stability, passenger packaging and docking clearance. Even an unrealistically low waterline at the float keel leaves only 4.5 ft below the swept propeller disks, versus the required 7-ft waterline-to-disk clearance. No compliant dock arrangement is demonstrated. Exterior float volume is used for an initial volume screen; eligible sealed internal volume and flooding are not established.

## Files and entry points

| Location | Purpose |
|---|---|
| `untitled.m` and `matchingdiagram.m` | Run-button/plot entry points matching the other concepts |
| `run_concept4_study.m` | Fixed-CAD geometry, source sizing, mission/budget and figures |
| `concept4_aero_hydro_requirements.json` | Geometry, RFP inputs, assumptions and plot controls |
| `Concept4_integration_assumptions.json` | Mission schedule and sizing margins |
| `OpenVSP_Import/` | Unmodified model copy, native CompGeom/DegenGeom exports, geometry reference and extraction scripts |
| `Results/Current/` | Current figures, data, geometry checks, mission ledger and summary |
| `regression_fixtures/` | Explicitly historical geometry/mission fixtures for regression tests |
| `run_concept4_resizing_study.m` | Optional optimizer that changes wing area; separate from the fixed-CAD baseline |
| `run_concept4_lightweight_fixedwing.m` | Optional wing-area study; retains imported body/tails and enforces span screens |

The older `run_concept4_sizing`, `run_concept4_constraints_12500` and `run_concept4_constraint_diagram_style` names now route to the fixed-CAD study. The actual evaluation is below 12,500 lb despite the compatibility filename. `plot_concept4_results` replots current saved data and does not read old 300/325/350-ft² candidate results.

## Verification

```matlab
geometry = verify_openvsp_geometry();
tests = test_concept4_integration();
```

The suite contains nine new CAD/analysis checks, thirteen inherited battery checks and twenty-two inherited route checks. Historical route tests deliberately load the archived historical requirements and summaries, so they do not silently assert that changed geometry must reproduce the old fuel result. New CAD tests verify the actual current geometry, area scaling, mass and mission accounting, normalization and explicit unverified limits.

To refresh after changing the CAD, rerun native extraction and rebuild the reference/input geometry before analysis. Keep source hashes and exports together. Do not update only the displayed span or replace the imported model without regenerating its areas and dimensions.
