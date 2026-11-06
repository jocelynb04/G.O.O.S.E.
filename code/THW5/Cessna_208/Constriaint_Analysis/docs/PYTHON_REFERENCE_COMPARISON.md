# Relationship to the user's original Python diagram

The user supplied `constraint_analysis(1).py` on 2026-11-06. A byte-for-byte copy is retained as `docs/reference/original_constraint_analysis.py`. It is a reference only, is not called by the MATLAB project, and does not add a Python/NumPy requirement to normal MATLAB use. Its companion tidal_requirements.json and route-output CSVs were not supplied, so the exact original numerical chart has not been reproduced.

## Presentation and envelope logic retained

- One W_TO/S versus W_TO/P_SL chart.
- Colored climb, balked-landing and cruise curves; a vertical landing wall.
- Green shading below the minimum active power-loading curve and left of the wall.
- An ACTIVE 180-KTAS cruise constraint, not a decorative speed reference.
- A yellow selected-design star, dotted vertical margin line, cross at the limiting W/P, arrow and annotated wing area, engine power, span and controlling curve.
- Power-loading and wing-loading margins relative to the current design point.

The MATLAB chart additionally marks the subset that requires no more than the retained 867-shp engine, and shows 164 KTAS as a dashed comparison only. This prevents full light-green shading from implying that arbitrary low W/P can be achieved with the original engine.

## Aircraft-specific differences

| Topic | Supplied Python | Conventional Caravan MATLAB |
|---|---|---|
| Default selected geometry/power | S=350 ft2, AR=8, P=1350 hp | S=279 ft2, AR about9.723, P=867 shp |
| Weight | Selected maximum12500 lb; actual plotted design weight comes from a CSV or command-line input | Reference MTOW9062 lb |
| Aero | CD0 and clean e read from a separate requirements file | Existing geometry-driven polar and float drag proxy |
| Climb | Configured CLmax-minus-margin and small-angle gradient correlation | User-requested3-degree path with exact trigonometric lift/vertical-work terms and capped optimum CL |
| OEI | Rejects n_engines<2; a powered OEI curve therefore belongs to a multi-engine input | Single engine gives zero remaining shaft power, no positive powered climb; glide reported separately |
| Takeoff | Generic TOP runway correlation, even if a condition is named water takeoff | Not added to this requested chart; the existing source helper remains available as a surrogate |
| Landing | Uses distance/0.265 to infer stall speed as if the distance were a ground-run correlation | Separates50-ft approach/flare from an explicit calibrated water-run proxy; still not validated hydrodynamics |
| Mission linkage | Can read converged mission weights, selected profile and leg CSVs | Uses current fixed reference aircraft; does not silently import unavailable route CSVs |

The original maximum12500-lb setting is not proof that the screenshot's plotted takeoff weight was12500 lb. Its `main` function can use mission-summary or sizing CSV weights, which were not part of this reference attachment.

The screenshot's positive red OEI curve is inappropriate for the conventional single-engine Caravan. Keeping that curve would incorrectly imply remaining engine power. The zero-powered-climb line is preserved instead. Likewise, reproducing a broad green region does not verify water performance or180-KTAS amphibian capability. The chart footer and constraint documentation state those limitations.
