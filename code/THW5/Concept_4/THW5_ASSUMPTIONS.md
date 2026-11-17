# THW5 Concept 4 — principal assumptions and evidence

16 November 2026. File locations below refer to the validation copy. J = `concept4_aero_hydro_requirements.json`; A = `Concept4_integration_assumptions.json`. These are source-input values, not validated aircraft hardware specifications.

| # | Classification and assumption | Value / units | Source location | Justification and evidence limit |
|---|---|---|---|---|
| 1 | Team gross-weight objective | 12,500 lb | J sizing block, lines 336–347; candidate summary team_weight_limit_lb | Common team comparison objective, not an RFP/certification maximum. 350-ft² result is 28.176 lb over; others have small uncertain margins. |
| 2 | Nominal mission operating point | 130 KTAS at 10,000 ft; all 868.976 nmi assigned to cruise | J:333–334, missions.std_mission.segments cruise (501–508) | Preliminary mission choice, distinct from required 180-KTAS capability. No credit for climb distance is conservative for cruise distance, but does not validate the complete operational mission. |
| 3 | Provisional geometry | AR 8, taper 0.4; two floats, each 27 × 4 × 3 ft; 12° deadrise, 4° planing trim | J:21–22, 72–77, 146–148 | Geometric/first-order tail-volume methods; selected dimensions/trim are illustrative. Require float drawings, loading/CG and experimental applicability checks. |
| 4 | High lift and lift-coefficient margin | CLmax clean 1.5, takeoff 1.8, landing 2.2; CLmax subtraction margin 0.20 (dimensionless) | J:113–116; c4_required_climb_hp.m:3–7 | Starting polar/high-lift assumptions; capability search subtracts 0.20 from CLmax and starts at 1.15 times the resulting stall speed. No additional blown-wing lift credit. Airfoil/flap/DEP validation absent. |
| 5 | Water surface energy allowances | Taxi 60 shaft hp × 8 min; takeoff 900 shaft hp × 2 min; landing 80 shaft hp × 3 min | A:2–15 | Preserves existing mission accounting. Takeoff gives 736.049 kW bus demand with assumed efficiencies. Not a resistance/thrust/acceleration or distance solution; experimental support absent. |
| 6 | Generator fuel/lapse surrogate | BSFC 0.4 lb/(shaft hp·h); lapse proportional to density ratio^0.8; continuous fraction 1.0 | J:166, 168–169; SeaplaneProp_Concept4.m | Preliminary constant fuel/lapse surrogate, not a validated turbogenerator map. Altitude, part-load fuel, thermal limits and installed capability need manufacturer data. |
| 7 | Fixed conversion/propulsive efficiencies | Motor 0.94; inverter 0.97; generator 0.93; rectifier 0.98; battery discharge 0.95, charge 0.92; propeller cruise/climb/loiter 0.82/0.80/0.72 | J:170–175, 189–191 | First-order energy accounting only. No hardware loss maps or six-propulsor installation data. Constant propulsive efficiency is not a static thrust model. |
| 8 | Installed battery properties and margins | 0.3 kWh/kg; 2 kW/kg; initial/min/max SOC 0.90/0.15/0.95; charge ceiling 200 kW, discharge ceiling 1,200 kW; energy and power margins each 10% | J:177–183; A:24; run_concept4_lightweight_fixedwing.m:27, 132–150; SeaplaneProp_Concept4.m:98 onward | Model pack assumptions, not demonstrated simultaneous hardware capability. Discharge bus limit = min(ceiling, installed kg × 2 × 0.95). These candidates give 809.654 kW. Power margin increases required power-based mass; it does not increase the physical specific-power limit. |
| 9 | Propulsion mass/continuous-rating assumptions | Motor/generator 5 kW/kg; inverter 10.6 kW/kg; turboshaft 4 kW/kg; six propellers at 15 kg each; motor continuous 85% nameplate; motor/generator sizing margins 1%/5% | J:163–167, 184–188; A:25,31 | Conceptual component mass/rating proxies with no selected installed hardware. Verify power-density definition, cooling and duty duration before claiming sustained operation. |
| 10 | Float/gear/installation weight budget | Floats 8% gross weight; attachments 2%; amphibious gear 5.7%; propulsion installation additions 4% wiring + 10% thermal + 5% nacelles + 4% mounts + 1% spinners | J:258–270; SeaplaneWeights.m | Preliminary statistical/placeholding budgets; Raymer/GA heritage is not validation for this DEP amphibian. Geometry-based structures and component buildup can exceed the narrow team-weight margins. |

## Requirements versus choices

The RFP values transcribed in J:285–330 include nine passengers and two pilots; 180-lb persons plus 50-lb baggage per passenger (2,430-lb payload); 1,000-statute-mile range and 45-minute reserve with balked landing; 180 KTAS at 10,000 ft at MTOW; 2,000-fpm SL and 500-fpm / 10,000-ft climb at MTOW; conditional multiengine 450-fpm SL OEI climb; span strictly below 65 ft; water takeoff and landing within 2,000 ft over a 50-ft obstacle at SL density altitude/MTOW; amphibious operation and no required shore charging. These are not all verified by the sizing run.

The 64-ft design span bound is a team modeling margin (A:29), not a replacement for the strict 65-ft requirement. The three candidate areas are study choices. Gross-weight closure, span and idealized AEO power are numerical screens; hardware, full mission feasibility and water performance remain unverified.

## Other operational approximations retained

A:21–23 sets nominal climb 1,000 fpm, electric balked climb 500 fpm and descent ten minutes. The reserve-entry maneuver climbs to 4,000 ft; reserve is 45 minutes at 120 KTAS / 4,000 ft. J:199–207 sets climb battery share 0.4 and cruise charging request -0.08. These operational choices differ from the required capability screens.

Descent consumes zero modeled propulsion power; approach markers consume zero time/power. Generator intended shutdown during electric phases is tracked, but physical start/stop dynamics and penalties are absent. No land taxi/takeoff/landing energy values are supplied; user-provided surface inputs are required and must not be replaced by test fixture values.

Water takeoff remains the principal feasibility gap. The hydro model supplies only bounded steady-planing/hydrostatic screening, not credible displacement-to-hump-to-liftoff resistance. NACA/propeller literature research has not provided a geometry- and scale-representative complete dataset. Do not invent coefficients, treat small propeller tests as full scale, or infer 2,000-ft compliance from the 900-hp allowance.

## Minimum remaining actions for THW5

1. Deliver the numerical trade with explicit assumptions/limitations; retain all three candidates and avoid a compliance/winner claim.
2. Reconcile the 350-ft² overweight status and small margins with the other concepts using common weight/mission assumptions.
3. Obtain representative float resistance and full-scale propeller thrust/power information, or present a clearly labeled feasibility sensitivity rather than a takeoff-distance claim.
4. Substantiate installed pack, motor and generator continuous/peak performance and thermal duty; check failure endurance, SOC reserve and recharge without shore power.
5. Supply defensible land-phase inputs and close water landing, buoyancy/compartment stability, sea-state, cabin and operational requirements before further compliance claims.
