# OpenVSP alignment report

Source: `C:\Users\Jason\OneDrive - Virginia Tech\Desktop\Fall 2026\Senior Design\Git\OpenVSP Models\Concept_2.vsp3`  
SHA256: `3aafa0563691d0c106ccdf1612b1000b7cbedc4b9ad45a49f51fa9501dbafece`  
Native OpenVSP 3.54.0 CompGeom and DegenGeom; units interpreted as feet from CAD export settings.

| Quantity | Imported baseline |
|---|---:|
| Wing reference area | 446.5728 ft² |
| Wing developed / projected span | 57.6000 / 57.5211 ft |
| Wing MAC | 7.83177 ft |
| Horizontal tail | 112.3672 ft² |
| Vertical tail | 95.5810 ft² |
| Vertical tail height / root chord | 11.1470 / 11.0640 ft |
| Fuselage length | 42 ft |
| Each nacelle length / sampled diameter | 5 / 5 ft |
| Each float length / sampled beam / depth | 25 / 3.00 / 2.40 ft |
| Each enclosed float volume | 108.2769 ft³ |
| Airframe external wetted area, propeller blades excluded | 2424.1224 ft² |
| Propeller count / diameter / blades per propeller | 2 / 8 ft / 5 |

At 12,000 lb and 62.316 lbf/ft³ freshwater, the current 80% reserve-buoyancy
assumption requires 346.62 ft³ total enclosed volume. The fixed
OpenVSP floats provide 216.55 ft³, supporting at
most 7497.1 lb at that requirement.
The study records this as a geometry failure and suppresses feasible-region
shading. Source power checks are still calculated independently.

The OpenVSP file and original Concept 2 files are unchanged. Wing trades scale
the imported wing; other components remain fixed. The old Caravan-sized fin
and volume-sized horizontal tail have been replaced with the imported tails.
Native intersected surface areas replace analytical approximations, including
both support-strut pairs. Existing float-system mass includes struts/rigging;
no second strut mass was added. Float and powertrain mass correlations remain
engineering assumptions; CAD does not determine equipment mass, CLmax, Cfe,
propeller efficiency, directional stability or mission dispatch.

`verify_openvsp_geometry` checks the source hash, baseline dimensions, wetted
area/drag consistency, fixed-component behavior during wing/weight trades and
the float-volume shortfall. `matchingdiagram` reruns the study and plots.

Rudder control matches the saved OpenVSP 25%-chord, 20%-80%-span definition:
14.33715 ft² planform. This replaces the
previous assumed full-span 30%-chord rudder area.

The first aligned mission run also fails battery-capacity search and reports
insufficient turbine propulsion/accessory power in a mission case. The
approximately 2996-kWh returned pack value is a failed search bound; its
associated mass budget is not a feasible aircraft prediction. Geometry matching
does not tune propulsion or mission requirements to force a pass.
