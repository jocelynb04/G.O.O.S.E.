# Revised OpenVSP Concept 1 results

The revised model is AmphibiousSeaplane_Concept1_Jason_Revised.vsp3 in Jason_Edits.
The original imported geometry is preserved in the prior model and backups.
Coordinates are interpreted as feet.

## Changes applied in OpenVSP

The wing has 713.714 ft² planform area, 64.5 ft projected span, 5.829 aspect
ratio, 14.745 ft root chord and 7.372 ft tip chord. Horizontal tail area is
105 ft² and vertical tail area is 60 ft². The horizontal tail was raised to
follow the taller fin. Floats and struts were shifted outward with the wing,
and support length was adjusted for wing dihedral at the new station.

OpenVSP 3.54.0 CompGeom was rerun on the revised shape. Evaluated airframe
wetted area is approximately 2,725.01 ft² after excluding rotating propeller
blades. The calculation includes intersections and mirrored components.
The retained default mesh reports two open meshes merged. A convergence
study remains necessary for detailed aerodynamic work.

## Selected system and model results

The design weight is 12,490 lb, turbine rating 1,500 shp, and electric rating
574.229 hp. The selected installed motor rating is now used for takeoff,
battery sizing and mission fuel. The model estimates 12,124.07 lb total
installed mission weight, 2,624.81 lb fuel burned, 74.088 kWh battery nameplate
capacity and 544.45 lb battery mass. The 130 lb hybrid installation allowance
replaces the original motor installation percentage allowance.

Cruise, climb, OEI climb, electric water takeoff, water landing, land landing
and span checks pass in the current equations. Wing loading is 17.50 lb/ft²
against a water-landing limit of 18.711 lb/ft². Modeled electric takeoff needs
535.85 hp versus 574.23 hp selected. Full-weight early return uses up to
302.59 hp turbine assist and retains about 40.05% battery charge after the
modeled go-around. The repeat-cycle charge and fuel balances were verified.

## Limits of the result

Landing CLmax 2.6 and the 300 Wh/kg, 8C battery system remain design targets.
Battery nameplate capacity includes an allowance for 80% retained capacity.
The model credits no Cfe reduction; CD0 0.01718 follows from evaluated area
at the retained Cfe 0.0045. Constant engine BSFC, altitude power availability,
immediate turbine assistance and water resistance/deceleration remain
preliminary. Hydrostatics, flooding, control/stability, structural design,
spray and sea-state behavior require their respective RFP analyses.

The external nacelle remains 5 ft long compared with the assumed 5.158 ft
bare engine. The engine/motor/coupling envelope needs a packaging revision.
The enlarged tails are geometric candidates and need stability and control
validation before the design is adopted as RFP-compliant.

Run run_concept1_openvsp in Jason_Edits for the current results. OpenVSP_
files represent this revised model. Older Concept1_ and RFP_ outputs are
historical. Source SHA-256 and dimensions are in OpenVSP_geometry_snapshot.json.
