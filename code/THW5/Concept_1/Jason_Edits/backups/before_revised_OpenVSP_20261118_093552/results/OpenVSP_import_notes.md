# OpenVSP geometry import

The supplied model is the external geometry source for the MATLAB configuration.
Coordinates are interpreted as feet from the 45-unit fuselage, 60-unit span
and 8-unit propellers. Confirm that unit convention before further sizing.

## Imported dimensions

| Part | Imported external dimensions |
|---|---|
| Wing | 360 ft², 60 ft section span, 59.963 ft projected span, 8 ft root and 4 ft tip chords, AR 9.98782, 2° dihedral |
| Horizontal tail | 52.5 ft², 14 ft span, 5 ft root and 2.5 ft tip chords |
| Vertical tail | 30 ft², 6 ft height, 7 ft root and 3 ft tip chords |
| Fuselage | 45 ft long, 7.5 ft maximum width, 7 ft maximum height |
| Nacelles | Two 5 ft long pods, 5 ft evaluated diameter |
| Floats | Two 9 ft long pods, 3 ft evaluated diameter |
| Float support struts | Two 4.5 ft long pods, 0.9 ft evaluated diameter |
| Propellers | Two 8 ft diameter, four-blade propellers |

Dimensions and parameters were extracted from the VSP3 XML and checked with
OpenVSP 3.54.0. CompGeom evaluated exposed wetted areas with intersections
and symmetry. Total airframe wetted area is 1,866.62 ft², excluding 36.98 ft²
of rotating propeller blades. Float strut area is included in the float
structure and airframe drag areas. CompGeom reported two open meshes merged.
Areas use the source file's tessellation and need mesh convergence for detailed
work. Tail arms are derived from wing/tail quarter-MAC stations and require a
separate CG and stability assessment.

## Updated analysis

The new shape uses the prior selected 12,490 lb weight, 1,500 shp turbine
rating, 574 shp electric rating, landing CLmax 2.6 target, and 300 Wh/kg,
8C pack target with 80% retained capacity. The old 15% zero-lift drag reduction
is removed for this shape. The calculation uses Cfe 0.0045 with imported
wetted area, giving CD0 0.02333. Neither Cfe nor CLmax is established by
geometric matching alone.

The imported point has wing loading 34.69 lb/ft². The water-landing limit is
18.71 lb/ft², equivalent to about 6,736 lb on the current 360 ft² wing. Water
takeoff requires about 938 hp electric versus the selected 574 hp. The model
passes cruise and climb power checks and fails these two water requirements.
At fixed imported aspect ratio and 12,490 lb, the 65 ft span limit also
prevents a wing large enough to satisfy the present landing correlation.

The mission diagnostic resizes the motor system to approximately 988 hp for
the takeoff power margin. Its fuel, battery and weight estimates apply to
that resized system. The selected-power pass/fail is exported alongside them.
They do not establish feasibility of the selected 574 hp system.

The modeled 5 ft nacelle is shorter than the assumed 5.158 ft bare engine,
before motor/coupling installation. Check the packaging envelope. The model
also supplies smaller tails than the earlier sizing case, requiring stability
and control analysis. Internal structure, engine maps, hull hydrodynamics,
waterline, spray, landing gear, and floodable compartments need separate data.

## Results

- `OpenVSP_geometry_snapshot.json` records the source SHA-256 and imported dimensions.
- `OpenVSP_compgeom.csv` retains the raw component analysis.
- `OpenVSP_design_point.csv`, `OpenVSP_power_checks.csv` and `OpenVSP_landing_checks.csv` record the current checks.
- `OpenVSP_matching_diagram.png` and `.fig` show the current imported point.
- `OpenVSP_mission_summary.csv`, `OpenVSP_mission_segments.csv`, and `OpenVSP_early_return.csv` describe the resized-system diagnostic.
- `OpenVSP_weight_breakdown.csv` records the geometry-driven structural estimates.

Earlier result files retain their historical calculations. The current
geometry supersedes their geometry-dependent pass/fail conclusions.
