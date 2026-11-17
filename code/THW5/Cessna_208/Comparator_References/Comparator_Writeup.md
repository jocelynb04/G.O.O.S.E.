# Cessna 208B Grand Caravan EX Amphibian comparator

**Responsible students:** [Name 1] and [Name 2]

## Aircraft and role

The team uses the PT6A-140-powered Cessna Grand Caravan EX Amphibian as its existing-aircraft comparator. Its high wing, conventional tail, single nose-mounted propeller, and amphibious floats make it relevant to the team's mission and provide published performance figures for checking our analysis. Two exploratory AMP-H570 installations examine how changes in propulsion affect the Caravan baseline. The team evaluates its candidate concepts separately.

## Geometry and aerodynamic model

The original OpenVSP model represents the fuselage, main wing, horizontal and vertical tails, floats and supports, amphibious landing gear, and centerline propeller. Its shared reference geometry supplies the MATLAB wing and tail dimensions. The separate twin installation model adds mirrored wing-mounted nacelles and propellers. MATLAB represents the fuselage with three sections and the tails with equivalent trapezoidal planforms.

| Reference dimension | OpenVSP-aligned value |
|---|---:|
| Main wing area | 279.00 ft² |
| Total main wing span | 52.083 ft |
| Fuselage length | 41.50 ft |
| Horizontal tail area | 70.04 ft² |
| Vertical tail area | 33.26 ft² |
| Float length, each | 31.75 ft |
| Total exterior wetted area | [Insert OpenVSP Comp Geom result in ft²] |

*Figure to insert: Conventional OpenVSP model showing the main wing, tail, floats, and original propeller.*

The drag model uses a parabolic polar. Its clean parasite term uses an equivalent skin-friction coefficient of 0.0055 multiplied by the MATLAB wetted-to-reference area ratio, plus a 0.012 float drag allowance. The current MATLAB geometry computes that area ratio analytically. The OpenVSP estimate will provide a separate check on the approximation. The comparison must account for which surfaces each estimate includes, especially the floats. Configuration increments represent flap, landing gear, and stopped-propeller effects. The chart uses a full-flap maximum lift coefficient of 2.2 from the course model. These aerodynamic inputs remain preliminary.

## Sizing, propulsion, and mission

Following the IHW3 workflow, we evaluate mission fuel and a wing-loading versus power-loading envelope. The conventional reference point uses the existing aircraft's 9,062-lb maximum takeoff weight, 279-ft² wing, and 867-shp PT6A-140 rating. This gives 32.48 lbf/ft² and 10.45 lbf/shp. This point represents the comparator configuration. The empty-weight model uses component estimates and a calibration residual to reach Textron's published 5,975-lb basic empty weight.

The PT6 model assumes constant specific fuel consumption of 0.65 lb/(shp·hr), a density-based shaft-power lapse, and propeller efficiencies of 0.80 in cruise and 0.75 in climb. The conventional chart project uses a 500-nmi, 150-KTAS mission at 10,000 ft with 800 lb of payload and a 45-minute reserve loiter at 4,000 ft. The separate original root mission uses 8,000 ft. The Level 2 model estimates climb from excess power, integrates cruise fuel over changing weight, and uses inherited fixed weight fractions for the ground, descent, and landing segments.

## Results and comparator checks

| Check | Result and interpretation |
|---|---|
| Basic empty weight | 5,975 lb by calibration to the published value. An independent weight prediction would require measured or independently estimated component weights. |
| Conventional cruise power | At 164 KTAS and the selected 10,000-ft condition, the model requires about 542 shp and estimates about 712 shp available. This supports a power feasibility check at the selected condition. Textron's product card gives 164 KTAS as maximum cruise and supplies limited detail for a matched-condition validation. |
| Climb | The chart screens a 3° climb, which implies about 438 ft/min at sea level at reference wing loading. Textron publishes a maximum climb rate of 1,212 ft/min. A matched-condition maximum-rate calculation is needed to compare those values directly. |
| Water landing | The screen combines the 50-ft approach and flare with a constant-deceleration water run. Its 2,004-ft calibration datum has an unverified water-landing definition. The modeled wall of 33.31 lbf/ft² is a sensitivity result. |

*Figure to insert: Conventional constraint chart showing the reference point, cruise curve, climb and balked-landing curves, and water-landing proxy.*

## Exploratory hybrid variants

The single study replaces the nose PT6 with one AMP-H570 and a 40-kWh pack. The twin study uses two wing-mounted units and two 20-kWh packs. Both default schedules use battery power during taxi, the prescribed takeoff power check, final approach, and landing roll. Combustion provides cruise propulsion and can recharge the packs. The electric takeoff segments establish whether the motors and batteries meet a prescribed load. Water takeoff distance needs thrust and hydrodynamic resistance modeling.

The single installation clears the modeled 164-KTAS cruise check by approximately 2.3 shp. The twin has about 13.2 shp of margin for the modeled 3° climb at 10,000 ft with one engine inoperative. That result addresses available shaft power and depends on assumptions for feathered-propeller drag and trim. The aircraft's directional control still requires analysis. The twin also incurs a substantial installation weight penalty, which reduces fuel capacity at the same payload and inherited takeoff limit. The two default hybrid missions use different payloads and cruise distances, so a common mission is needed before comparing fuel or energy measures of merit.

## What the comparator establishes

The comparator gives the team a published amphibian weight, power, and cruise benchmark and a consistent way to compare loading and power margins. The strongest constraints on interpretation are the calibrated empty weight, lumped float and nacelle drag, and provisional water-run methods. A component-level OpenVSP wetted-area result and an independent performance check at matched conditions will strengthen the benchmark before it is used to compare the team's candidates.

## References

- [Textron Aviation Cessna Caravan Amphibian Series product card](https://cessna.txtav.com/-/media/cessna/files/product-cards/turboprop/caravan_amphibian_productcard.pdf)
- [Ampaire AMP-H570 specifications](https://www.ampaire.com/amp-h570)
- [OpenVSP Comp Geom documentation](https://openvsp.org/api_docs/3.55.0/group___computations.html)
- [Caravan comparator model and inputs](README.md)
