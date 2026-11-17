# Concept 4 — THW5 preliminary design package

Updated 16 November 2026, MATLAB R2026b Update 1. This validation copy contains the corrected coupled-sizing results and mission-route architecture. Concept 4 remains one of four concepts before team downselect; no candidate is selected here. Numerical convergence and passing tests do not establish aircraft compliance.

## Architecture and scope

Amphibious twin-pontoon aircraft, cruciform tail, six electric propulsors and one series-hybrid turbogenerator. The intended sequence is:

**Electric ground operations → Electric takeoff → Hybrid climb → Hybrid cruise → Electric landing**

`Concept4Mission.m` dispatches phases; `c4_mission_route.m` selects surfaces and configurations; `SeaplaneProp_Concept4.m` accounts for generator, battery and motor power. Ground operations, takeoff, landing and modeled balked landing are electric-only. Climb uses the existing battery share (phi = 0.4); cruise requests charging (phi = -0.08), subject to generator and battery limits. Generator intended operating state is tracked separately from zero electrical output. Physical spool, startup/shutdown transients, idle fuel and transition penalties are not modeled.

Descent and approach are distinct from landing. Each existing descent retains its ten-minute zero-power approximation. Approach is an explicit zero-time, zero-power unverified marker. Neither approximation proves realistic approach energy or noise. Landing retains the existing three-minute, 80-shaft-hp water allowance.

Four directional routes are represented:

| Departure → arrival | Surface selection | Additional inputs before energy calculation |
|---|---|---|
| Water → water | water / water (default) | Existing provisional water phase allowances |
| Water → land | water / land | runway_landing |
| Land → water | land / water | land_taxi, runway_takeoff |
| Land → land | land / land | land_taxi, runway_takeoff, runway_landing |

Options use `departure_surface`, `arrival_surface`, and `surface_inputs`. Each additional phase input is a structure with `shaft_hp` and `duration_min`; there are no invented land-performance defaults. Inspect `mission.plan('std_mission',options)` before `mission.run(W,'std_mission',false,options)`. Missing land inputs raise `C4:MissingSurfaceInputs`. These methods do not write outputs. Route support is phase/energy bookkeeping, not verified runway or water performance.

Water surface operations use gear up; runway operations use gear down. Clean climb uses gear up without a retraction penalty. Land balked landing retains gear down; timing remains unverified. No arrival taxi energy is added.

## Current coupled-sizing results

Source of truth: `results/fixedwing_{300,325,350}/summary.json`. These are updated coupled-sizing outputs, not the historical baseline. The mission is the default Water-to-Water route.

| Quantity | 300 ft² | 325 ft² | 350 ft² |
|---|---:|---:|---:|
| Converged / iterations | yes / 24 | yes / 22 | yes / 25 |
| Gross weight, lb | 12,397.036 | 12,442.802 | 12,528.176 |
| OEW including battery, lb | 8,354.428 | 8,438.776 | 8,548.862 |
| Payload, lb | 2,430 | 2,430 | 2,430 |
| Mission fuel, lb | 1,612.608 | 1,574.026 | 1,549.314 |
| Battery mass, lb | 939.464 | 939.464 | 939.464 |
| Battery capacity, kWh | 123.414 | 121.931 | 120.955 |
| Installed battery bus discharge limit, kW | 809.654 | 809.654 | 809.654 |
| Peak modeled battery bus discharge, kW | 736.049 | 736.049 | 736.049 |
| Total motor nameplate rating, shaft hp | 1,606.228 | 1,581.533 | 1,564.162 |
| Generator engine nameplate rating, shaft hp | 1,024.795 | 1,019.254 | 1,024.476 |
| Required 2,000-fpm SL climb shaft hp | 1,351.776 | 1,330.993 | 1,316.374 |
| Required 500-fpm / 10,000-ft climb shaft hp | 710.167 | 685.832 | 666.749 |
| Required 180-KTAS / 10,000-ft cruise shaft hp | 633.044 | 632.954 | 636.197 |
| Final mission SOC, % | 23.561 | 24.186 | 24.679 |
| Final closure residual, lb | +0.02047 | +0.01842 | -0.02063 |
| Margin below 12,500-lb team target, lb | +102.964 | +57.198 | -28.176 |
| Span, ft | 48.990 | 50.990 | 52.915 |

The 12,500-lb value is a **team target**, not an RFP maximum. The 350-ft² candidate exceeds it. Smaller candidates' margins are much smaller than likely model uncertainty. Increasing wing area reduces modeled mission fuel and motor rating but increases OEW and gross weight in this three-point trade; generator rating is not monotonic. This is not a global optimum or a hardware selection.

Capability power is evaluated at no less than 12,500 lb (actual gross weight for the heavier candidate). Installed motor nameplate is distinct from continuous output (85% of nameplate), and generator engine shaft rating is distinct from electrical bus power. The battery limit is the lesser of the configured 1,200-kW ceiling and installed mass × assumed specific power × discharge efficiency; 809.654 kW is a result for these packs, not a universal constant.

## Reproduction and output protection

Work from this validation folder or a new isolated copy. Use a fresh MATLAB session when switching source copies; do not put duplicate original/archived classes on the active path. Check `pwd` and `which -all` for the runner, mission, geometry, aero, propulsion, weights and climb helper before calculations. Clear stale classes/functions before constructing model objects if necessary; do not reset the MCP server's MATLAB path.

The active inputs are case-sensitive names:
- `concept4_aero_hydro_requirements.json`
- `Concept4_integration_assumptions.json`

Main entrypoint (each call writes candidate outputs):

~~~matlab
candidate300 = run_concept4_lightweight_fixedwing(300);
candidate325 = run_concept4_lightweight_fixedwing(325);
candidate350 = run_concept4_lightweight_fixedwing(350);
~~~

No-argument execution selects 325 ft² only. Each call constructs its models, iterates mass/power/mission coupling, returns a structure/history, and overwrites `summary.json` and `iteration_history.csv` in its corresponding candidate directory. It does not produce water distances, trial liftoff speed, or a combined figure.

Existing results in the original project are tracked by Git. Running there can overwrite tracked historical results. Preserve current outputs in a **new, nonexisting** backup location and verify hashes before rerunning. The full `baseline_backup` and `figure_backup_20261116` directories remain protected in the validation copy only and are not transferred. Portable regression fixtures contain only byte-for-byte historical summary copies in `regression_fixtures/historical_summary_300ft2.json`, `historical_summary_325ft2.json` and `historical_summary_350ft2.json`. Tests use these fixtures, not backup directories. These historical component sizes and reference values are separate from the current corrected outputs in `results/fixedwing_*`; do not replace one with the other.

The legacy `run_concept4_sizing.m` / `Concept4Sizing.m` method and `plot_concept4_results.m` belong to a different, approximately 15,604-lb baseline. They are not the final candidate workflow. Legacy result/status files do not describe the updated candidates. There is no combined predownselect runner in this package.

## Final THW5 figures

| Figure | Use and interpretation |
|---|---|
| [Actual candidate comparison](results/thw5_final/candidate_comparison.png) | Final weights, fuel, battery energy, installed ratings and SOC; explicit team-target line |
| [Coupled-sizing convergence](results/thw5_final/sizing_convergence.png) | Finite, monotonic residual magnitudes for all three; convergence alone is not compliance |
| [Constraint screen](results/constraints_12500/concept4_mission_constraint_diagram.png) | **Fixed 12,500-lb** AEO motor/span curves and an assumed landing-stall boundary, with actual-weight 300/325/350-ft² candidate markers on one axis; not full-aircraft feasibility |
| [Motor matching](results/constraints_12500/motor_matching_12500.png), [power loading](results/constraints_12500/motor_power_loading_12500.png), [generator rating](results/constraints_12500/generator_rating_12500.png) | Supplemental fixed-weight parameter sweeps |

PNG/FIG/PDF versions of actual-candidate and convergence plots are under `results/thw5_final`; the constraint-screen PDF is there too. The screen's editable FIG remains under `results/constraints_12500`. [Verified comparison CSV](results/thw5_final/verified_candidate_comparison.csv) contains every scalar numeric/logical summary field.

The constraint calculations retain their validated cruise/climb equations. The final single-axis diagram reads each current `results/fixedwing_*/summary.json` and plots W/S = actual gross weight / wing area and W/P = actual gross weight / total installed motor nameplate. The obsolete 350-ft² / 1,350-hp initial marker is removed. [Candidate marker data](results/constraints_12500/concept4_candidate_markers.csv) records the plotted values, summary paths and team-weight margins. The 350-ft² candidate is explicitly labeled 28.2 lb above the 12,500-lb team target.

The background curves and span lines remain at 12,500 lb. Required installed power is the maximum cruise/climb demand after the continuous-rating fraction and margin; therefore allowable W/P lies **below the minimum** of the individual curves. Actual-weight overlays are context, not direct pass/fail tests against that fixed-weight background. The minimum motor-power point near 512 ft² is a fixed-weight screening minimum, not a coupled candidate or minimum-weight design. Green shading is the intersection of the AEO motor-power screen, the 64-ft design-span bound and the provisional landing-stall limit. The left and right limits are 24.414063 and 41.897820 lbf/ft²; neither the plot edge nor the stall assumption establishes water-field performance. Dashed motor-out curves omit failed-propeller drag/yaw and remain unverified. Water takeoff/landing, battery-only operation, hardware, and sustained power/energy remain unverified by this diagram.

The maximum wing-loading boundary uses an assumed landing stall speed of 75 KIAS, landing CLmax of 2.2, standard sea-level density, and landing-to-takeoff weight ratio of 1.0. This is a preliminary conceptual screening assumption rather than a specified RFP requirement. Water takeoff and landing distance compliance remains unverified.

The diagram uses rho = 0.002377 slug/ft³ and 75 knots = 126.585739 ft/s, giving maximum W/S = 0.5 rho V² CLmax / (W_L/W_TO) = 41.897820 lbf/ft², with the screened side to the left. KIAS is approximated as equivalent airspeed at standard sea level without calibration corrections. This assumption is local to the diagram; active JSON inputs and coupled sizing are unchanged. The curve CSV records separate span/stall masks and both wing-loading limits.

The main diagram command overwrites its PNG/FIG, fixed-weight curve CSV, candidate-marker CSV and final constraint-screen PDF. The separate sweep command overwrites its CSV and three supplemental PNGs. Back up existing outputs to a new location before regeneration:

~~~matlab
constraints = run_concept4_constraint_diagram_style;
sweep = run_concept4_constraints_12500;
~~~

For the candidate-overlay correction, only the main diagram was regenerated. The pre-edit source, documentation and constraint outputs are preserved with SHA-256 checks in `review_backups/constraint_diagram_before_candidates_20261116/`. This isolated local review backup is not a delivery artifact and must not be staged or added to the MATLAB path.

The older `concept4_constraint_final_candidates.png/.fig` was left unchanged and is **excluded from final delivery figures**: it contains historical annotations, omits 350 ft², and has no supplied reproducible producer. All nine previous constraint artifacts are preserved in `figure_backup_20261116/constraints_12500` in the validation copy only; this backup is not part of the repository transfer. See [figure provenance](results/thw5_final/FIGURE_PROVENANCE.md).

## Tests and numerical validation

MATLAB R2026b Update 1 has executed the updated three candidate runs. All converged; all 35 unit tests passed (22 route tests, 13 battery tests), and the separate integration test passed in Stage 7. Final iteration residuals have no sign reversals or growing magnitudes; no nonfinite values were found. The final summary closure check differs from the last iteration-history residual by design.

Safe tests (no candidate output-writing runner):

~~~matlab
testResults = runtests({'Concept4MissionRouteTest.m','SeaplanePropBatteryTest.m'});
assert(all([testResults.Passed]));
test_concept4_integration
~~~

Route tests cover surface selection, electric/hybrid routing, generator intent, SOC continuity, missing-input handling and historical Water-to-Water replay at fixed historical component sizes. Synthetic land fixtures are tests, not aircraft performance data. Battery tests cover candidate-specific mass limits, configured ceilings and over-limit rejection. Historical fixed-component mission reproduction is distinct from updated coupled sizing: corrected climb sizing legitimately changed component ratings and coupled results.

Stage 7 static analysis of 32 MATLAB files found no blocking errors and two legacy array-growth suggestions (`Concept4Sizing.m:108`, `matching_envelope_C4.m:44`). The smoke/legacy sizing workflows are not substitutes for these tests and are not required for reproducing final candidates.

## Methods and file inventory

| Files | Role |
|---|---|
| `run_concept4_lightweight_fixedwing.m` | Current fixed-area coupled candidate sizing; energy/power battery sizing; installed-pack enforcement |
| `Concept4Mission.m`, `c4_mission_route.m` | Route plan and time-segment fuel/SOC accounting |
| `SeaplaneGeom.m`, `SeaplaneAero_Concept4.m` | Planform/tail/wetted geometry; component parasite drag and induced polar |
| `SeaplaneProp_Concept4.m` | Series-hybrid power balance, ratings/lapse, efficiencies, pack limits/mass |
| `SeaplaneWeights.m` | Preliminary component/system OEW including battery |
| `c4_required_climb_hp.m`, `constraint_cruise_speed_C4.m` | Capability screens; climb polar evaluated at each trial speed |
| `segment_climb_C4.m`, other `segment_*.m` helpers | Mission/legacy segment calculations; capability and mission speed searches need not be identical |
| `SeaplaneHydro_Concept4.m` | Hydrostatics and bounded steady-planing screening, not full water takeoff |
| `run_concept4_constraint_diagram_style.m`, `run_concept4_constraints_12500.m` | Fixed-weight figure/table producers |
| `Concept4MissionRouteTest.m`, `SeaplanePropBatteryTest.m`, `test_concept4_integration.m` | Current validation tests |
| `Concept4Sizing.m`, adapters/verification, `sizing_pass.m`, legacy runner/plotter | Retained older integration workflow; not final candidate evidence |
| `Concept_4_requirements.txt` | Older classroom reference; not active input |
| `c4_*.m`, JSON/table writers and remaining helpers | Shared implementation utilities; inspect dependency resolution before switching copies |

The lightweight method fixes wing area and sizes the battery by the greater of mission energy and modeled battery power, unlike the older full-installed-motor battery mass method. Its 10% battery **power** mass margin is hardcoded at `run_concept4_lightweight_fixedwing.m:27`; it is separate from the JSON 10% battery energy margin, 1% motor margin and 5% generator margin. Corrected climb capability evaluates the speed-dependent polar at each trial speed. Mission climb remains a separate operational climb calculation.

## Requirements, assumptions and limitations

See [ten principal assumptions and evidence](THW5_ASSUMPTIONS.md) for values, units, source locations and justification. Requirements are transcribed in `concept4_aero_hydro_requirements.json:285–330`; the original RFP should remain the final authority. The mission assigns all 868.976 nmi (1,000 statute miles) to 130-KTAS cruise at 10,000 ft, without climb-distance credit. The 180-KTAS / 10,000-ft capability screen is separate. Payload is nine passengers plus two pilots with stated baggage, totaling 2,430 lb. The explicit electric balked landing and 45-minute reserve are retained.

**Unresolved delivery limitations:** water takeoff and landing within 2,000 ft over 50 ft, representative float displacement/hump resistance, propeller static/forward-speed data, hardware power/thermal capability, generator-out endurance, motor-out drag/yaw, mission/recharge without shore power, missing land-phase performance/energy data, buoyancy below cabin floor/flooding/heel, sea-state/crosswind dispatch, cabin/egress, IFR/FIKI, noise and detailed mass/drag substantiation.

The existing **900-shaft-hp / two-minute water takeoff** remains a provisional energy allowance. Its approximately 736-kW battery bus peak is imposed, not derived from water acceleration or obstacle clearance. A planing correlation cannot represent the initial displacement/hump regimes. No verified takeoff distance or full-aircraft compliance is claimed.

Several JSON prose notes/status flags predate the implemented solver (for example “no coupled driver” and “future mission model”). Inputs were deliberately not edited; use current code and candidate outputs for numerical status, and retain unverified engineering flags until evidence exists.

## References retained from active inputs

These references support methods and research direction, not validation of selected hardware or geometry:
- D. P. Raymer, *Aircraft Design: A Conceptual Approach*; course planform, wetted-area and GA statistical weight methods. Applicability to this DEP floatplane remains unvalidated.
- [NASA OpenVSP Parasite Drag Tool](https://www.nasa.gov/reference/openvsp-parasite-drag-tool/).
- [NASA Electrified Aircraft Propulsion — Aircraft Configurations](https://www.nasa.gov/eap-aircraft-concepts/aircraft-configurations/).
- D. Savitsky (1964), [Hydrodynamic Design of Planing Hulls](https://doi.org/10.5957/mt1.1964.1.4.71), and the ITTC-1957 friction correlation within its valid regime.
- [14 CFR 23.2310 buoyancy](https://www.ecfr.gov/current/title-14/chapter-I/subchapter-C/part-23/subpart-D/section-23.2310), as cited by the active JSON; this package does not establish regulatory compliance.

## Transfer status

Ready for team review as a preliminary numerical trade package, with limitations attached. Not ready to claim complete RFP compliance or select a winner. Transfer only reviewed validation changes into the existing team Concept 4 folder after approval; preserve original/historical outputs and teammates' Concepts 1–3. The approved transfer includes validated source, tests, portable regression fixtures, documentation and final outputs only. Full backups remain validation-only. No commit or push has been performed; review the transfer before committing.

Final single-axis presentation: the matching diagram uses one large axis, a focused wing-loading/power-loading window, distinct candidate markers with offset labels, a compact legend below the axis, a 300-dpi PNG and editable FIG, and a vector PDF. There is no separate zoom or subplot. Candidate coordinates, engineering curves and stall/span calculations are unchanged from the approved screens. A marker can lie slightly above the fixed-weight curve because its own converged weight differs from the 12,500-lb background; this is shown without relocating the marker and is not a matched-weight compliance determination. Local backups under `review_backups` are excluded from commits.
