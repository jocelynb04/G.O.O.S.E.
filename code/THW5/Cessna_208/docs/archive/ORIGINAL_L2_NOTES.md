Historical notes from the supplied L2 package; dependency/run-status statements are superseded by README.md.

# Grand Caravan EX Amphibian (C208B) — 12-model MATLAB adaptation

**Status: UNVALIDATED research baseline.** Not suitable for flight planning, performance guarantees or certification. The original 12 MATLAB Grader files in the parent folder have not been modified. The included 12 `.m` files are a separate experimental adaptation, and depend on instructor-supplied framework utilities that were not uploaded (`ttpa_disciplines`, `matching_envelope`, `run_constraints`, `wing_loading_sweep`, `get_state`, `get_con`, framework base classes/readers). The entire package has **not** been run in MATLAB; numerical agreement with the manufacturer has **not** been established.

## Aircraft identity — NOT the standard Caravan Amphibian

Cessna Grand Caravan **EX Amphibian (208B EX)**, one **PT6A-140**, **867 shp**, **9,062 lb MTOW**, **5,975 lb basic empty weight**, **279 ft² wing**, **52 ft 1 in span**. Published usable fuel **2,246 lb/335 gal**; max cruise **164 KTAS**, max range **813 nmi** (different operating points); max climb **1,212 fpm**; manufacturer water takeoff run **2,000 ft**, water takeoff distance over 50 ft **3,271 ft**. Source: https://cessna.txtav.com/en/turboprop/grand-caravan-ex and https://specialmissions.txtav.com/en/float-operations .

**Landplane vs amphibian:** EX landplane basic empty weight 5,310 lb, EX Amphibian 5,975 lb: **net +665 lb**. This is not a bare float assembly weight. At MTOW with full usable fuel the arithmetic remaining is **841 lb** (9062-5975-2246). Manufacturer's **876 lb** full-fuel payload refers to a 9097 lb maximum ramp basis, not MTOW. The 2025 product card with 8,807-lb MTOW refers to the non-amphibious EX; do not mix variants.

## Files and detailed change log (in original assignment order)

1. **TtpaProp.m**: `J.caravan.enabled` switches to EX PT6A-140. One engine, JSON BSFC/efficiency values, 867-shp reference for provisional dry engine mass scaling and 63-in family-level engine length. Piston `5.47*bhp^.78` is not applied in EX mode. `sigma^0.65` is only a surrogate turboprop lapse, not a PT6A-140 engine deck. With one engine, OEI means no usable shaft power. Max-continuous ratio 1.0 is a placeholder.
2. **TtpaGeom.m**: EX geometry reads the included complete EX JSON directly: AR derived from 52ft1in/279ft², taper, wing shape, tail volume parameters, 41ft7in exterior length split into nose/cabin/tail, and exterior fuselage dimensions. Cabin published length 16ft9in. The nose-integrated engine has no *separate wing-nacelle cylinder* wetted area. Original TTPA branch retains its exact Grader-compatible `l_engine=0.32*obj.prop.P_engine^0.424`; EX branch uses the modeled PT6A length. Float geometry and mounting structure wetted areas are not yet resolved; a *single proxy CD0 increment* in Aero is used instead. No double-counting in both aero and `S_wet`.
3. **TtpaAero.m**: Dependent `CD0` remains based on `J.aerodynamics.Cfe*S_wet/S_ref`, with uncalibrated **+0.012** float/strut/interference CD0 in EX mode. Cfe **0.0055** is the preliminary light-single value (not calibrated EX CFD/flight test). Flap/gear CLmax/drag increments remain instructional assumptions and may be inappropriate.
4. **TtpaWeights.m**: Geometric wing/tails/fuselage and installed PT6A assumed weights; conventional tricycle gear fraction removed for EX floats, plus **+665 lb** *net empty-weight configuration difference proxy*. **Not a true float weight**. To match the published **5975 lb basic empty weight at MTOW=9062 lb**, a separate **+2162.70 lb calibration residual** in the JSON is added to the original build-up, in addition to the net 665-lb float configuration proxy. **This is a calibration anchor, not an independently predicted physical component, and it would be misleading to call this a validated OEW estimate.** The OEW vs BEW definitions differ. Structural coefficients, installed engine factor, and unmodeled equipment require subsequent identification.
5. **constraint_cruise_speed.m**: Same `drag_based` power equation; now reads revised aero, single turbine power, and cruise constraints from the EX JSON (demo **150 KTAS at 8000 ft**, not 164 KTAS max).
6. **segment_cruise_L2.m**: Actual-CL, Breguet subsegment cruise physics unchanged. Demo **500 nmi at 150 KTAS** is an illustrative mission, not Textron's 813-nmi advertised maximum range.
7. **segment_loiter_L2.m**: Actual-CL endurance equation unchanged. Demo **45-minute loiter at 110 KTAS/4000ft** in JSON is an assumed reserve segment. No extra 6% buffer is silently stacked on it (reserve_fuel_fraction=0).
8. **segment_climb_L2.m**: Excess-power climb retained. Must calibrate PT6A lapse, max-continuous power, aerodynamic drag, climb speed, temperature limits to manufacturer **1212 fpm max climb** under corresponding conditions.
9. **run_mission_L2.m**: Same type-based mission dispatch. Generic Roskam 0.984/0.992 ground/descent fractions are NOT water-takeoff fuel-flow physics; water hydrodynamic drag/run must be independently modeled.
10. **SizingSteps.m**: Weight closure and relaxation arithmetic unchanged. `w=0.30` in example is provisional; original optimum `0.45` applied to a different plane.
11. **sizing_pass.m**: Maintains write/constraint/size/mission/empty/closure/residual ordering. Revised JSON changes OEI condition to AEO for single engine, but **generic Roskam takeoff/landing formulas are not hydrodynamic water-performance constraints**. Matching envelope results are not validated for EX.
12. **sizing_mainloop.m**: Same convergence logic; initial guess W0=9062, P0=867, S0=279, with a changed numerical starting relaxation 0.30. A converged triplet is an algorithmic result only, not an aircraft validation.

## Original JSON integrated, not just overlaid

`GrandCaravanEX_requirements_IHW3.json` is a **full edited copy** of the user-provided `Ttpa_requirements_IHW3.json`. It preserves schema keys used by course classes and readers (geometry, aerodynamics, propulsion, weights, constraints, missions, sizing), and adds `caravan`, `reference_aircraft`, `model_assumptions`. Original `_src...`/`_comment` explanatory strings were removed so they do not falsely claim twin-piston provenance for EX assumptions. Source JSON has NOT been changed.

The empty-weight coefficient build-up alone gives approximately **3812 lb**, so the **+2162.70-lb unallocated calibration residual** is material. It should be replaced by a defensible systems/structure breakdown when better component data become available.

The JSON constraint array still has six rows to fit original framework expectations. The fourth (original `Climb OEI`) is explicitly replaced by **5000-ft Climb AEO demonstration**. The first two are **takeoff/landing surrogate requirements** using published water-distance numbers but are NOT valid water takeoff/landing physics; they should not be interpreted as validated water performance. If the course constraint reader uses fixed indices/assumptions, adapt it separately.

## Quick MATLAB Online sanity check

In this folder on MATLAB's path:

```matlab
p = grand_caravan_ex_params();
out = grand_caravan_ex_benchmark();
check = grand_caravan_ex_check_json('GrandCaravanEX_requirements_IHW3.json');
```

The checks need **no** course framework, and test only identity and basic benchmark arithmetic. If the framework is installed and supports selecting the EX JSON explicitly, build the bundle with **that file** and examine propulsion, geometry, CD0, OEW, mission, and matching in that order. **Do not** call `ttpa_disciplines()` with no path and assume it automatically selects the new JSON: the provided helper might hardcode the original JSON.

## Most important missing data before meaningful sizing

PT6A-140 performance deck / power vs density altitude and temperature / fuel flow vs shaft power / rated time limits; float hull geometry and wet area / hydro takeoff drag / float and retractable gear structural weight; actual wing and tail drawings, root/tip chords and moments; precise zero-lift drag including floats; calibrated flap/gear polars; mission and reserve definitions. Do not assert that a 164-KTAS max-cruise and 813-nmi max-range occur simultaneously.
