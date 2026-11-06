# Caravan EX Amphibian only: constraint diagram

Run `analysis = run_constraint_analysis;` from this project root in MATLAB Desktop. Run `verify_constraint_analysis` to check syntax, execute the regression tests and regenerate the diagram. MATLAB R2025a is the tested release; no additional toolbox is required.

The active input is `config/Constraint_analysis.json`. The only cruise case is164 KTAS, the retained Caravan EX amphibian benchmark. The proposed-aircraft180-KTAS requirement,165-KTAS comparison curve and orange comparison region are absent from the default calculation and plot. The earlier comparison versions are retained only as historical notes and regression fixtures.

The chart includes:

- Clean3-degree climb capability constraints at sea level and10000ft, as previously requested. These are path-angle requirements, not constant-ft/min maximum climb performance.
- Balked landing at the inherited3% gradient, with landing flaps and wheels retracted. Three percent is not3 degrees.
- The164-KTAS cruise power constraint at10000ft using full modeled max-continuous power.
- The water-landing-over50-ft proxy wall using the inherited2004-ft total-distance target.
- The red zero-powered-climb OEI line: with one conventional engine failed there is no remaining shaft power. Positive powered OEI climb is excluded from normal AEO shading; enabling it eliminates the feasible region.
- A yellow Caravan reference star and callout at W/S=9062/279=32.4803 lb/ft2 and W/P=9062/867=10.4521 lb/shp. Its reference wing area279ft2, power867shp and span52.08ft are fixed. It is not an optimized proposed-aircraft point.

Green is below the minimum active AEO power-loading curve and left of the water wall. The removed180-KTAS requirement no longer restricts this envelope. The broader region does not move the actual Caravan reference star. Shading permits engine resizing; low W/P points may require more than867shp at reference weight. The optional horizontal867-shp line stays hidden by default.

The numerical results may retain an additional buffered sizing candidate; it is not the plotted reference point and needs geometry, weight and mission iteration before being treated as a design proposal.

## Equations

For fixed climb angle gamma, L=beta*W_TO*cos(gamma), CD=CD0+K*CL^2 and required shaft power is [D*V+beta*W_TO*V*sin(gamma)]/(550*eta_p). The angle branch selects a capped minimum-power CL and uses the existing propulsion altitude lapse. Required rate of climb is60*V*sin(gamma). Cruise uses the existing drag-based shaft-power balance. The power-loading limit is referred to rated sea-level shaft power using kP=P_available/P_SL.

The water proxy uses approach distance (50ft minus assumed flare-entry height)/tan(approach angle), an assumed flare distance, and water run V_touchdown^2/(2*a_effective). Its effective deceleration is calibrated to the retained reference distance, not measured hydrodynamics. The public reference does not establish the2004-ft datum's exact over-obstacle water-landing definition. The wall and the green region are therefore provisional screening results, not validated water performance.

The frozen reference drag polar, approximate turbine lapse, component/float assumptions and calibrated empty-weight baseline remain. No hybrid,180-KTAS design requirement, new-aircraft marker, mission-weight closure or actual float water-run dynamics are introduced by this chart.

## Outputs

The runner writes PNG, vector PDF, editable FIG, numerical CSV and saved MAT results to `outputs/`. The verifier adds `CONSTRAINT_VERIFICATION.txt`. Reviewed plot copies and the text report are intentionally included under `docs/`; generated `outputs/` contents are ignored for GitHub.


Current-folder update2026-11-06: landing CLmax2.2, cruise10000ft in the analysis and main mission climb/cruise. Caravan-only164KTAS chart and reference point retained. Water-landing calibration and landing beta0.975 remain assumptions. Earlier verification records are historical until regenerated.
