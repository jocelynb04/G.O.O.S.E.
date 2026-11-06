# Conventional Caravan EX Amphibian constraint analysis

## Run

In MATLAB Desktop R2025a, select this extracted repository root as Current Folder:

```matlab
analysis = run_constraint_analysis;
verify_constraint_analysis
```

The runner sets up the source paths automatically. Only MATLAB is required. It produces a single mission-constraint chart patterned after the supplied example. The 180-KTAS cruise curve is an ACTIVE boundary; a dashed165-KTAS curve is shown for comparison only. The chart includes the two climb-altitude constraints, balked landing, the over-50-ft water-landing proxy wall, OEI zero-powered-climb limit, engine-power cap and actual reference design point. The yellow star marks the existing Caravan comparator and its callout reports actual reference wing area, engine power and span. A separate buffered 164-KTAS sizing candidate remains in the numerical result, but is not the plotted star. This project is the conventional PT6A-140 amphibian, with no hybrid energy system.

Outputs under `outputs/`:

- `caravan_constraint_diagram.png`: presentation image.
- `caravan_constraint_diagram.pdf`: vector chart.
- `caravan_constraint_diagram.fig`: editable MATLAB figure.
- `constraint_curve_data.csv`: numerical curve samples.
- `constraint_analysis_results.mat`: conditions, curves, masks, reference checks, candidates and engine-out glide estimate.
- `CONSTRAINT_VERIFICATION.txt`: verification report.

For a custom settings file: `analysis = run_constraint_analysis('my_settings.json');`. To calculate without plotting: `analysis = run_constraint_analysis([],false);`.

## Requirements and conventions

The active analysis settings are in **config/Constraint_analysis.json**, separate from the original aircraft/mission JSON, which has not been changed.

| Requirement | Default | Meaning |
|---|---|---|
| Horizontal axis | W_TO/S, 10–60 lbf/ft2 | Takeoff wing loading |
| Vertical axis | W_TO/P_SL, lbf/shp | Takeoff weight divided by installed sea-level shaft power |
| Climb at sea level | 3-degree flight-path angle | User-requested gradient, not fixed ft/min |
| Climb at 10000 ft | 3-degree flight-path angle | Same angle; true climb speed and ft/min change with density |
| Climb configuration | Clean; CL limited to CLmax minus existing margin | Floats remain in the clean aircraft drag proxy |
| Balked landing | 3% gradient, sea level, landing flaps, wheels retracted, beta 0.975 | Inherited design assumption: 3%, NOT 3 degrees |
| Cruise capability | 180 and 164 KTAS at 8000 ft | Uses full modeled max-continuous power; not an arbitrary cruise throttle restriction |
| Maximum installed shaft power | 867 shp at 9062-lb reference MTOW | Excludes candidate points requiring a larger engine |
| Water landing | 2004-ft total target over a 50-ft obstacle | Reference-calibrated proxy, described below |
| Landing weight fraction | 0.975 | Assumed W_landing/W_TO |
| Curve and water-wall selection buffer | 5% | Applied when a sampled point satisfying both buffers exists |
| Positive powered OEI climb enforced? | False | Curve shown, but not imposed on the normal AEO region; imposing it makes the region empty |

A 3-degree path has gradient tan(3 deg) = 0.0524078, or 5.24%. Vertical speed is `60*V_TAS_fps*sin(3 deg)`, not a fixed value independent of airspeed. At the reference W/S, the calculated clean climb speeds are about 82.7 KTAS at sea level and 96.3 KTAS at 10000 ft, corresponding to about 438 and 510 ft/min. These are the rates IMPLIED by the prescribed path and modeled selected CL; they are not asserted maximum aircraft climb rates.

You can instead select `climb_requirement_type: "rate"` and provide `climb_rates_fpm: [value_at_SL, value_at_10000]`. The rate branch uses a quasi-steady small-angle approximation and explicitly specified ft/min. The default angle branch uses the exact trigonometric lift and vertical-work terms.

## Climb, balked landing and cruise equations

For prescribed climb angle gamma and weight fraction beta:

```
q = 0.5*rho*V^2
L = beta*W_TO*cos(gamma)
CL = L/(q*S)
CD = CD0 + K*CL^2
P_required = [D*V + beta*W_TO*V*sin(gamma)]/(550*eta_p)
(W_TO/P_SL)_max = 550*eta_p*kP /
    {beta*V*[cos(gamma)*CD/CL + sin(gamma)]}
```

Here `kP` is available shaft power at the condition divided by rated sea-level takeoff power, including altitude lapse, rating and selected power setting. For the angle branch, minimum required power at each W/S gives

```
CL_opt = [tan(gamma) + sqrt(tan(gamma)^2 + 12*K*CD0)]/(2*K)
```

CL is capped at `CLmax - CL_stall_margin`. The model uses the existing configured drag polar and propeller efficiencies, including the assumed float drag. This determines which climb speed gives that angle with least required power in the simplified model. It is not an AFM speed schedule.

Balked landing uses the same angle-based power balance with `gamma = atan(0.03)` and the landing-flap, wheels-retracted polar. Wheels must not be assumed down for a normal water landing; amphibian floats and their drag are still present.

Cruise retains the tested drag-based constraint:

```
CL = beta*(W_TO/S)/q
CD = CD0 + K*CL^2
(W_TO/P_SL)_max = 550*eta_p*kP / [beta*V*(CD/CL)]
```

A cruise point violating the modeled clean lift-coefficient margin is rejected. Full modeled max-continuous power is used to screen maximum capability. The original mission's 85% setting is retained only as an informational comparison setting in the analysis JSON; it does not constrain the capability curves.

## 180-versus-165-KTAS comparison band

The solid cyan180-KTAS curve is an active target constraint. The dashed purple165-KTAS curve is a lower-speed comparison requirement using the SAME frozen Caravan drag polar, weight ratios, altitude and power assumptions. The published amphibian benchmark remains164 KTAS;165 is a rounded comparison requested by the user.

Green is below the target envelope and left of the water wall. Orange is above the180-KTAS envelope but below the165-KTAS envelope, clipped to the same climb, balked-landing and water constraints. Points in the orange band therefore meet165 KTAS but fail180 KTAS in the mathematical screening model. Where a common non-cruise constraint controls both envelopes, the band disappears. This is a difference in REQUIREMENTS, not proof that a proposed aircraft has achieved180 KTAS or is better overall.

The reference marker is explicitly the Caravan COMPARATOR, not a selected design for the new aircraft. No proposed-aircraft marker is plotted at the user's request. Demonstrating superiority needs the proposed aircraft's own aerodynamics, powertrain, weights, reserves and performance evidence. The current inherited model predicts a marginal full-power180-KTAS balance for the Caravan; it must not be tuned or relabeled to conceal that inconsistency with published performance.

### Origin of the reference point and867-shp line

The existing model stores reference takeoff weight9062 lb, wing area279 ft2 and engine rating867 shp. These give W/S=9062/279=32.4803 lb/ft2 and W/P=9062/867=10.4521 lb/shp. The span52.08 ft comes from the retained reference geometry. The point is a direct benchmark calculation, not the result of optimization.

The earlier horizontal line was added as an OPTIONAL installed-engine-size restriction: at fixed9062 lb, points below W/P10.4521 require MORE than867 shp. It is not a new aerodynamic constraint, not a certified boundary, and not a limit on the new aircraft. It is hidden by default in this comparison. Set `show_installed_power_boundary=true` to display it as reference information. The previous internal engine-limited sizing candidates remain available in the results but are not plotted or presented as the new design.

The default shaded regions allow engine resizing; they do not claim all points can be reached with the existing867-shp Caravan. Positive powered OEI is excluded from AEO shading. Water landing remains a reference-calibrated proxy.

## Water landing over a 50-ft obstacle: what is known

The inherited model stores a 2004-ft landing distance, and Textron's float-operations webpage lists that number for the Grand Caravan EX. The public webpage does not explicitly establish that number as a **WATER landing over a 50-ft obstacle** for the modeled weight/configuration. The new analysis treats 2004 ft as an editable design target and calibration datum; it does not claim the missing distance definition has been verified.

Instead of treating the entire over-obstacle distance as a runway ground roll, the proxy separates approach, flare and water run:

```
S_air = (h_obstacle-h_flare_entry)/tan(approach_angle) + S_flare
S_water = V_touchdown^2/(2*a_effective)
V_touchdown = k_touchdown*V_stall
V_stall^2 = 2*beta*(W_TO/S)/(rho*CLmax_landing)
S_total = S_air + S_water
```

Defaults are obstacle height 50 ft, flare-entry height 10 ft, a 3-degree approach, 150-ft horizontal flare and touchdown speed 1.15 times stall speed. These are modeling assumptions, not a validated approach/flare schedule. The corresponding upper wing-loading wall is

```
(W_TO/S)_max = rho*CLmax_landing*a_effective*(S_target-S_air) /
              [beta*k_touchdown^2]
```

The default method infers a constant effective deceleration from the reference MTOW, wing area, CLmax and the inherited total-distance datum. It gives about 0.224 g and a nominal wall near 33.31 lbf/ft2 with the chosen 0.975 landing beta. This is a circular REFERENCE CALIBRATION, not independent water-landing validation. It must not be treated as measured hydrodynamic deceleration. The code also reports a user-configurable +/-25% deceleration sensitivity interval, not a statistical confidence interval.

For a fully assumption-driven study, use `water_landing.method: "assumed_deceleration"` and set `effective_deceleration_g_assumed`. The same approach/flare geometry then applies without reference fitting. A target shorter than the assumed airborne/flare part is rejected. Actual AFM float-supplement landing data, speeds, weight and wind/temperature conditions are needed to replace the proxy. There is no wave, water drag, wind, flare dynamics or surface-condition model here.

## OEI with one engine

For one conventional engine, `(n_engines-1)/n_engines = 0`: no shaft power remains after an engine failure. A positive powered climb constraint therefore has **W/P limit zero**, and no positive finite W/P point meets it. The red line shows this explicitly. Making the installed engine bigger does not solve its own failure.

The normal shaded regions are AEO. Set `require_powered_oei: true` to enforce the impossible positive powered-climb requirement and obtain no feasible region in either speed case. `analysis.all_constraints_including_positive_oei_feasible` is always false for this conventional single-engine configuration.

An unpowered glide is a different calculation. The report estimates best L/D using the existing clean float polar plus its assumed stopped-propeller drag increment. The current model yields roughly L/D 11.66, 97.8 KTAS and 846 ft/min sink at reference weight/sea level. These are illustrative aerodynamic estimates; propeller failure state, AFM glide speed and actual drag are not validated. No OEI regulatory compliance or go-around guarantee is claimed.

## Feasible region and design points

At a given W/S, the tightest positive power-loading bound is the minimum of the two climb curves, balked-landing curve and the cruise curve. Requirements permit points **below** this envelope: lower W/P means more installed engine power. Water landing permits points **left** of its wall. An optional867-shp hardware cap at reference weight would impose a LOWER W/P bound, `9062/867 = 10.4521 lbf/shp`: points below that require more than the retained engine rating.

The yellow star is the Caravan COMPARATOR reference point, `9062/279 = 32.4803 lbf/ft2` and `9062/867 = 10.4521 lbf/shp`. Its callout shows S=279 ft2, P=867 shp, span=52.08 ft and the tightest active power curve. This is the existing aircraft, not a silently resized design.

The calculated results also retain a separate buffered sizing candidate for the benchmark-supported 164-KTAS case. Its objective remains largest W/P with the configured curve/wall margins; this candidate is not used as the chart's reference-design star. There is no universal unique 'most feasible' design without choosing an objective and margins.

The polar and aspect ratio are frozen at the reference aircraft across this matching chart. Candidate S and P are algebraic conversions of W/S and W/P at the reference weight. A changed wing/engine would change wetted area, mass, drag and fuel requirements; the candidate must be iterated through the sizing/geometry model and checked against mission, weight, tank, stall and other requirements. The separate sizing candidate is not an already validated Caravan redesign.

No water takeoff-distance curve, structural loading, CG, ceiling, thermal/torque, service certification or full mission closure requirement is added to this chart. Those constraints can further shrink or eliminate the region.

## Sources

- Textron Aviation, Float Operations, Grand Caravan EX table: https://specialmissions.txtav.com/en/float-operations . Supports the 164-KTAS cruise benchmark and inherited 2004-ft landing-distance number, without the detailed water/obstacle definition needed here.
- Wipaire, Wipline 8750 Floats: https://www.wipaire.com/wipline-floats/wipline-8750-floats/ . Supports the float installation context and reference 867-shp EX/9062-lb table entries; detailed landing performance remains a missing input.

The cited pages include different installation/weight options. This model deliberately retains its original 9062-lb EX amphibian baseline rather than silently adopting another gross-weight kit. Source summaries were checked on 2026-11-06.


Comparison-band update: `analysis.comparison_band` contains the lower/upper W/P arrays and valid mask. The unit test samples the band and checks that its interior fails180 KTAS while satisfying165 KTAS and the common landing wall. The optional867-shp line and older sizing calculations are not imposed on this full comparison band.
