# Concept 1 RFP design point review

Concept 1 meets the three matching-diagram limits for the preliminary model at 12,490 lbf, 18.30 lbf/ft² and 8.33 lbf per rated turbine shp. The diagram supports a preliminary sizing decision. Full RFP compliance requires physical and operational evidence.

## Why the three boundaries matter

- The span boundary sets the minimum wing loading at 18.244 lbf/ft². At fixed takeoff weight and aspect ratio, moving left increases wing area and span. The selected 64.9 ft span has 1.2 in of margin to the strict 65 ft limit.
- The water-landing boundary sets the maximum wing loading at 18.711 lbf/ft². Moving right raises stall and touchdown speeds and increases the modeled distance from the obstacle to a stop.
- The black upper envelope is the lowest allowed weight-to-power ratio limit among the flight and takeoff curves at each wing loading. The airplane needs more installed power as it moves down the chart at fixed weight. Electric water takeoff governs at the selected point with the electric-to-turbine rated power ratio held fixed. The design rates 574 shp electric for a modeled minimum of 546 shp.

## Evidence by requirement

| Requirement | Current evidence and disposition |
|---|---|
| Wingspan below 65 ft | 64.9 ft in the model. Check the final tip geometry and installation tolerance. |
| Project MTOW below 12,500 lb | Design point 12,490 lb. Installed mission buildup 12,379 lb includes the 130 lb hybrid installation allowance. The buildup assumes a 15% reduction in clean zero-lift drag and a 300 Wh/kg, 8C battery pack sized for 80% retained capacity. |
| Nine passengers, two pilots, 50 lb baggage per passenger | 2,430 lb included in the model. Check seat layout and loading and CG limits. |
| 1,000 statute mi with full payload and 45 min IFR reserve | Sizing mission covers 868.976 nmi cruise plus a 45 min reserve loiter. Close against a measured drag buildup, engine power/fuel maps, and supplier pack performance. |
| Balked landing at the start of reserve | The model adds the balked landing before reserve and checks the full-weight early return. It assumes turbine assistance is available at the command. Demonstrate turbine readiness, clutch engagement, propulsion faults, and the emissions interpretation. |
| No required ground charging | The modeled repeat cycle balances onboard charging in cruise and reserve. Validate generator, inverter, battery power, cooling, and operational recharge margins. |
| No tailpipe emissions during takeoff, landing, and on-water operations | Normal modeled water takeoff and final approach are electric, with zero shaft power on the landing run. Water taxi and maneuvering energy, all associated system loads, and the assisted missed-approach interpretation remain open. |
| Water takeoff and landing over 50 ft within 2,000 ft at MTOW, MSL ISA, calm water | The equations estimate 1,805 ft takeoff and 1,979 ft landing. The landing threshold is CLmax ≈ 2.543 with the nominal water deceleration assumption, or equivalent deceleration coefficient ≈ 0.1462 with CLmax 2.6. Nominal deceleration coefficient is 0.15. The takeoff resistance coefficient can increase from 0.10 to about 0.1501 before the model reaches 2,000 ft. These are individual model sensitivities. Obtain hull resistance, spray, rotation, and water deceleration data from the tow-tank campaign. |
| 180 KTAS and 500 ft/min best climb at 10,000 ft density altitude | The curves clear the design point. At the design point, cruise and 30 kW DC charging together need about 771 shp shaft power. Check the installed engine/propeller maps at altitude. |
| 2,000 ft/min sea-level climb and 450 ft/min with one engine inoperative | The performance equations clear the point. Verify installed power, propeller efficiency, feathering/asymmetric drag, and directional control. |
| Land operation and 20 KTAS land/water crosswinds at OEW | The project has a supplemental land-landing distance proxy. Land takeoff and the crosswind requirements need dedicated analyses. |
| Fresh-water reserve buoyancy and two adjacent compartments flooded | Required subfloor buoyant volume is at least approximately 360 ft³ at 12,490 lb. Evaluate actual watertight geometry, equilibrium, stability, and exit height after flooding each pair of adjacent compartments. |
| Heel stability through 20°, 40 KTAS gusts, and water directional control | Verify hydrostatic righting moments, wing clearance, float immersion, and steering/control through displacement, planing, and takeoff. |
| Sea state 3 with more than 98% dispatch reliability | Requires a sea-state operating envelope and dispatch analysis. |
| Wing-over-dock clearance | The RFP geometry needs 7 ft from the waterline to the lowest relevant wing or propulsor point. Check loaded waterlines, heel, and propeller position. |
| Dual controls and single-pilot capability | Verify cockpit layout, controls, systems, and single-pilot workload. |
| Turnaround within 30 min | Verify dock procedures, boarding, baggage, and refueling or charging at the intended operating sites. |
| IFR, known icing, and pilot visibility | Verify avionics, anti-ice/de-ice equipment and loads, and cockpit sight lines. |
| Passenger interior | Verify nine seats, 35 in pitch, 17.5 in seat width, 2 in armrests, and a 20 in aisle below the armrests. |
| Program schedule, Part 23 design evidence and desirable attributes | Verify certification plan and technology readiness for the 2036 target. Develop structural, stability, hydrostatic, and economic evidence and evaluate noise, maintainability, and beaching in the report. |

Sources are the Tidal Flight Seaplane RFP 2026, the [revised design point](Concept1_revised_design_point.csv), the [constraint checks](Concept1_revised_constraint_checks.csv), and [14 CFR § 23.2310](https://www.ecfr.gov/current/title-14/chapter-I/subchapter-C/part-23/subpart-D/section-23.2310). The RFP applies the buoyancy requirement to under-cabin-floor volume and separately specifies the two-compartment flooding case.
