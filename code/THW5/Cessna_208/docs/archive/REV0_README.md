# Grand Caravan EX Amphibian standalone MATLAB project

Extract the ZIP first. In MATLAB Desktop R2025a (the tested release), choose the extracted `GrandCaravanEX_Amphibian_Standalone` folder as Current Folder. Do not run from inside Windows ZIP preview. No Aerospace Toolbox or external course folders are needed. Only MATLAB is required; tests use MATLAB's bundled unit test framework.

Run these commands in the MATLAB Command Window:

```matlab
addpath(pwd)
result = run_caravan;       % reference aircraft: mission, fuel and constraints
verify_project             % syntax scan, unit tests and sizing demonstration
sized = run_caravan(true);  % optional exploratory resizing
```

If old course copies are already on your path, restart MATLAB, select this folder, then run `addpath(pwd,'-begin')`. `which ttpa_disciplines -all` should list this project's version first. The report is `MATLAB_VERIFICATION.txt`; test and demonstration results are also saved in `verification_results.mat`.

`result.mass_margin_lb` is MTOW minus modeled empty weight, payload and mission fuel. `tank_margin_lb` compares required fuel with the 2246-lb reference usable fuel. Negative margins mean the specified mission is infeasible under the assumptions. Positive margins do not establish power, stall, flight envelope or water performance compliance. The envelope outputs are surrogate design constraints.

## Inputs and provenance

`GrandCaravanEX_requirements_IHW3.json` is the active, complete EX adaptation supplied in the earlier package. `Original_IHW3.json` is an unchanged archival copy of the user's IHW3 JSON, not an active twin-engine aircraft input. `ttpa_requirements_path` resolves the active JSON relative to this package, independent of current working directory. `ttpa_disciplines(path)` accepts another complete EX JSON. It validates key mission and propulsion inputs; malformed/missing schema fields produce errors rather than silently switching aircraft.

The twelve adapted model files are TtpaProp, TtpaGeom, TtpaAero, TtpaWeights, constraint_cruise_speed, segment_cruise_L2, segment_loiter_L2, segment_climb_L2, run_mission_L2, SizingSteps, sizing_pass and sizing_mainloop. Eleven are preserved byte-for-byte from the supplied L2 folder. The sizing loop now checks all three residuals and synchronizes returned gross weight and mission fuel. `PROVENANCE.json` records original and revised hashes. Historical model-by-model notes are in `ORIGINAL_L2_NOTES.md`.

The missing base classes, readers and mission/constraint helpers were recovered from the user's IHW3 student_starter and bundled here. PropulsionBase2 signatures/comments now match the adapted implementation. AircraftState uses an internal dry ISA troposphere equation instead of toolbox atmosisa; pressure altitude input is limited to 0–36089 ft. Active mission input validation restricts altitude to the 20000-ft reference aircraft ceiling. The discipline factory initializes power, area and weight so the baseline runs immediately. No external framework path is needed.

## Equations and limits

The original geometry, wetted area, drag polar, engine scaling, component weights, Breguet cruise/loiter, excess-power climb, constraint and closure equations remain. Cruise uses subsegment actual lift coefficient; loiter freezes lift-to-drag ratio at the segment entry. Fixed takeoff/descent/landing fractions remain 0.984/0.992/0.992. Minimum-power climb is quasi-steady and does not enforce stall margin, speed schedules or thermal/torque limits. Cruise/loiter do not automatically reject power-shortfall or stall conditions. These require separate review before interpreting a mission result.

BSFC 0.65 lb/(shp hr), efficiencies 0.80/0.75/0.72, sigma^0.65 turbine power lapse, engine weight/length scaling, Cfe 0.0055 and float drag increment 0.012 are provisional. There is no installed PT6A-140 engine deck, off-standard temperature model, hydrodynamic float model, wave/wind effect, structural sizing, stability or certification analysis.

The 5975-lb empty-weight anchor includes an unallocated 2162.70-lb residual and a 665-lb net landplane/amphibian difference proxy. It is calibrated basic empty weight, not an independently validated operating empty weight. Payload must include crew and all operational equipment missing from that anchor. Manufacturer benchmark values are inherited from the source package and were not independently revalidated for this software revision.

Takeoff/landing constraints apply generic runway correlations to the inherited 3271-ft/2004-ft water-distance inputs. These mix distance definitions and are illustrative surrogates only; they cannot demonstrate water takeoff/landing capability. Single-engine OEI constraints are excluded; this project models powered AEO operation only. The 500-nmi, 150-KTAS, 8000-ft mission with 800-lb payload and 45-minute loiter is an example. Additional reserve fraction is zero; it is not a regulatory reserve determination. Advertised speed and range maxima are not simultaneous mission claims.

The optional sizing loop resizes the aircraft away from the reference Caravan. Its numerically converged geometry and engine are not a proposed certified Caravan configuration. Relaxation 0.10 was tested successfully; the inherited 0.30 oscillated. Convergence only establishes fixed-point numerical closure on a 500-point wing-loading grid. A modified mission may fail to climb, have no feasible envelope, or not converge; inspect its diagnostics instead of treating the last iterate as a solution.

## Verification

`verify_project` scans all root MATLAB files, runs tests for atmosphere values, reference weight anchoring, geometry/aero coupling, mission mass balance, cruise constraint algebra, closure arithmetic, invalid inputs, inability to climb and sizing convergence. It then reports required MATLAB products and runs the full demonstration. The included transcript records the actual R2025a results. Numerical tests verify implementation consistency, not agreement with flight-test data. No flight-planning or certified-performance use is supported.
